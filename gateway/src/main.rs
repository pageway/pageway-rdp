#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod web_tls;

use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::{anyhow, Context, Result};
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{ConnectInfo, State};
use axum::http::{header, HeaderValue, StatusCode, Uri};
use axum::response::{Html, IntoResponse, Response};
use axum::routing::get;
use axum::{Json, Router};
use futures_util::{SinkExt, StreamExt};
use hyper_util::rt::{TokioExecutor, TokioIo};
use hyper_util::server::conn::auto::Builder as ConnectionBuilder;
use hyper_util::service::TowerToHyperService;
use ironrdp_rdcleanpath::{RDCleanPathMessage, RDCleanPathPdu};
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::crypto::ring;
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{ClientConfig, DigitallySignedStruct, Error as TlsError, SignatureScheme};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio_rustls::{TlsAcceptor, TlsConnector};
use tower::Service;
use tower_http::services::ServeDir;
use web_tls::TrustInfo;

#[derive(Clone)]
struct AppState {
    destination: String,
    static_dir: PathBuf,
    trust: Arc<TrustInfo>,
    tls: bool,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct FileConfig {
    listen: Option<String>,
    destination: Option<String>,
    r#static: Option<String>,
}

struct Options {
    listen: SocketAddr,
    destination: String,
    static_dir: PathBuf,
    config_dir: PathBuf,
    log: Option<PathBuf>,
}

fn parse_args() -> Result<Options> {
    let mut listen: SocketAddr = "0.0.0.0:7172".parse().unwrap();
    let mut destination = "127.0.0.1:3389".to_owned();
    let mut static_dir = default_static_dir();
    let mut config_dir = default_config_dir();
    let mut log: Option<PathBuf> = None;

    let args: Vec<String> = std::env::args().skip(1).filter(|a| a != "serve").collect();

    if let Some(pos) = args.iter().position(|a| a == "--config") {
        let path = args.get(pos + 1).ok_or(anyhow!("--config needs a value"))?;
        if let Some(parent) = Path::new(path).parent() {
            config_dir = parent.to_path_buf();
        }
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("failed to read config file {path}"))?;
        let file: FileConfig =
            serde_json::from_str(&text).with_context(|| format!("invalid config file {path}"))?;
        if let Some(value) = file.listen {
            listen = value
                .parse()
                .context("invalid listen address in config file")?;
        }
        if let Some(value) = file.destination {
            destination = value;
        }
        if let Some(value) = file.r#static {
            static_dir = PathBuf::from(value);
        }
    }

    let mut args = args.into_iter();
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--config" => {
                args.next();
            }
            "--listen" => {
                listen = args
                    .next()
                    .ok_or(anyhow!("--listen needs a value"))?
                    .parse()?
            }
            "--destination" => {
                destination = args.next().ok_or(anyhow!("--destination needs a value"))?
            }
            "--static" => {
                static_dir = PathBuf::from(args.next().ok_or(anyhow!("--static needs a value"))?)
            }
            "--log" => {
                log = Some(PathBuf::from(
                    args.next().ok_or(anyhow!("--log needs a value"))?,
                ))
            }
            "--cert-dir" => {
                config_dir = PathBuf::from(args.next().ok_or(anyhow!("--cert-dir needs a value"))?)
            }
            other => return Err(anyhow!("unknown argument: {other}")),
        }
    }

    Ok(Options {
        listen,
        destination,
        static_dir,
        config_dir,
        log,
    })
}

fn default_config_dir() -> PathBuf {
    std::env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
        .join("Pageway")
}

fn default_static_dir() -> PathBuf {
    std::env::current_exe()
        .ok()
        .and_then(|exe| exe.parent().map(|dir| dir.join("web")))
        .filter(|web| web.is_dir())
        .unwrap_or_else(|| PathBuf::from("frontend/dist"))
}

#[tokio::main]
async fn main() -> Result<()> {
    let options = parse_args()?;
    init_logging(options.log.as_deref())?;

    let listen = options.listen;
    tracing::info!(%listen, destination = %options.destination, "Pageway starting");
    let web_tls = web_tls::load_or_create(&options.config_dir)?;
    let listener = tokio::net::TcpListener::bind(listen).await?;
    tracing::info!(fingerprint = %web_tls.trust.fingerprint, "HTTPS ready");

    loop {
        let (stream, peer) = tokio::select! {
            accepted = listener.accept() => accepted?,
            () = shutdown_signal() => break,
        };
        let state = AppState {
            destination: options.destination.clone(),
            static_dir: options.static_dir.clone(),
            trust: web_tls.trust.clone(),
            tls: false,
        };
        let tls = web_tls.acceptor.clone();
        tokio::spawn(async move {
            if let Err(error) = serve_connection(stream, peer, state, tls).await {
                tracing::debug!(%peer, %error, "HTTP connection ended");
            }
        });
    }
    Ok(())
}

async fn serve_connection(
    stream: TcpStream,
    peer: SocketAddr,
    mut state: AppState,
    tls: TlsAcceptor,
) -> Result<()> {
    let mut first = [0u8; 1];
    let length = stream.peek(&mut first).await?;
    if length == 0 {
        return Ok(());
    }
    state.tls = first[0] == 0x16;
    let app = build_app(state);
    if first[0] == 0x16 {
        let stream = tls
            .accept(stream)
            .await
            .context("browser TLS handshake failed")?;
        serve_http(stream, peer, app).await
    } else {
        serve_http(stream, peer, app).await
    }
}

async fn serve_http<S>(stream: S, peer: SocketAddr, app: Router) -> Result<()>
where
    S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Unpin + Send + 'static,
{
    let service = app
        .into_make_service_with_connect_info::<SocketAddr>()
        .call(peer)
        .await?;
    ConnectionBuilder::new(TokioExecutor::new())
        .serve_connection_with_upgrades(TokioIo::new(stream), TowerToHyperService::new(service))
        .await
        .map_err(|error| anyhow!(error))?;
    Ok(())
}

fn build_app(state: AppState) -> Router {
    Router::new()
        .route("/", get(root_handler))
        .route("/rdp", get(ws_handler))
        .route("/pageway/ping", get(|| async { StatusCode::NO_CONTENT }))
        .route("/pageway/trust.json", get(trust_handler))
        .route("/pageway/ca.der", get(ca_der_handler))
        .route("/pageway/ca.cer", get(ca_pem_handler))
        .route("/pageway/ca.cmd", get(ca_command_handler))
        .route("/pageway/ca.mobileconfig", get(ca_profile_handler))
        .fallback_service(static_service(&state.static_dir).expect("static service"))
        .with_state(state)
}

async fn root_handler(
    State(state): State<AppState>,
    ConnectInfo(peer): ConnectInfo<SocketAddr>,
    uri: Uri,
) -> Response {
    let limited = uri
        .query()
        .is_some_and(|query| query.split('&').any(|part| part == "limited=1"));
    let trust_page = !state.tls && !peer.ip().is_loopback() && !limited;
    let file = if trust_page {
        "trust.html"
    } else {
        "index.html"
    };
    match tokio::fs::read_to_string(state.static_dir.join(file)).await {
        Ok(html) => Html(html).into_response(),
        Err(error) => (StatusCode::NOT_FOUND, format!("{file}: {error}")).into_response(),
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct TrustResponse {
    host: String,
    fingerprint: String,
}

async fn trust_handler(State(state): State<AppState>) -> Json<TrustResponse> {
    Json(TrustResponse {
        host: state.trust.host.clone(),
        fingerprint: state.trust.fingerprint.clone(),
    })
}

async fn ca_der_handler(State(state): State<AppState>) -> Response {
    (
        [(
            header::CONTENT_TYPE,
            HeaderValue::from_static("application/x-x509-ca-cert"),
        )],
        state.trust.ca_der.clone(),
    )
        .into_response()
}

async fn ca_pem_handler(State(state): State<AppState>) -> Response {
    download_response(
        state.trust.ca_pem.clone().into_bytes(),
        "application/x-x509-ca-cert",
        &format!("pageway-{}.cer", state.trust.host),
    )
}

async fn ca_command_handler(State(state): State<AppState>) -> Response {
    download_response(
        state.trust.windows_command().into_bytes(),
        "application/octet-stream",
        &format!("Pageway-Trust-{}.cmd", state.trust.host),
    )
}

async fn ca_profile_handler(State(state): State<AppState>) -> Response {
    download_response(
        state.trust.mobileconfig().into_bytes(),
        "application/x-apple-aspen-config",
        &format!("Pageway-{}.mobileconfig", state.trust.host),
    )
}

fn download_response(body: Vec<u8>, content_type: &'static str, filename: &str) -> Response {
    let disposition = HeaderValue::from_str(&format!("attachment; filename=\"{filename}\""))
        .unwrap_or_else(|_| HeaderValue::from_static("attachment"));
    (
        [
            (header::CONTENT_TYPE, HeaderValue::from_static(content_type)),
            (header::CONTENT_DISPOSITION, disposition),
        ],
        body,
    )
        .into_response()
}

fn init_logging(path: Option<&Path>) -> Result<()> {
    let filter =
        tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into());
    if let Some(path) = path {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let file = Arc::new(
            std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open(path)
                .with_context(|| format!("failed to open log file {}", path.display()))?,
        );
        tracing_subscriber::fmt()
            .with_env_filter(filter)
            .with_ansi(false)
            .with_writer(move || file.try_clone().expect("log file clone"))
            .init();
    } else {
        tracing_subscriber::fmt().with_env_filter(filter).init();
    }
    Ok(())
}

fn static_service(dir: &Path) -> Result<ServeDir> {
    if !dir.is_dir() {
        tracing::warn!(?dir, "Static directory not found, serving nothing");
    }
    Ok(ServeDir::new(dir))
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
}

// ------------------------------------------------------------- RDP websocket

async fn ws_handler(ws: WebSocketUpgrade, State(state): State<AppState>) -> Response {
    ws.on_upgrade(move |socket| async move {
        if let Err(error) = run_session(socket, &state).await {
            tracing::info!(%error, "Session ended with error");
        }
    })
}

async fn run_session(mut ws: WebSocket, state: &AppState) -> Result<()> {
    let request = tokio::time::timeout(Duration::from_secs(30), ws.recv())
        .await
        .context("timed out waiting for the RDCleanPath request")?
        .context("websocket closed before the RDCleanPath request")?
        .context("failed to read the RDCleanPath request")?;

    let request = match request {
        Message::Binary(bytes) => bytes,
        other => {
            return Err(anyhow!(
                "expected a binary RDCleanPath request, got: {other:?}"
            ))
        }
    };

    let message = RDCleanPathPdu::from_der(&request)
        .context("failed to decode the RDCleanPath request")?
        .into_message()
        .context("invalid RDCleanPath request")?;

    let RDCleanPathMessage::Request {
        destination: requested,
        x224_connection_request,
        ..
    } = message
    else {
        return Err(anyhow!("unexpected RDCleanPath message type"));
    };

    tracing::info!(destination = %requested, "RDCleanPath request");

    let destination = &state.destination;

    let mut tcp = tokio::time::timeout(Duration::from_secs(10), TcpStream::connect(destination))
        .await
        .context("timed out connecting to the RDP server")?
        .with_context(|| format!("failed to connect to the RDP server at {destination}"))?;

    tcp.write_all(x224_connection_request.as_bytes()).await?;
    let x224_connection_response = read_tpkt(&mut tcp).await?;

    let chain = Arc::new(Mutex::new(Vec::new()));
    let tls_stream = tls_connect(tcp, destination, chain.clone()).await?;

    let response = RDCleanPathPdu::new_response(
        destination.clone(),
        x224_connection_response,
        chain.lock().expect("chain lock").clone(),
    )?
    .to_der()?;

    ws.send(Message::Binary(response.into())).await?;

    tracing::info!("RDCleanPath exchange complete, relaying session");

    relay(ws, tls_stream).await
}

async fn read_tpkt(stream: &mut TcpStream) -> Result<Vec<u8>> {
    let mut header = [0u8; 4];
    stream.read_exact(&mut header).await?;
    if header[0] != 3 {
        return Err(anyhow!("invalid TPKT version byte: {}", header[0]));
    }
    let length = u16::from_be_bytes([header[2], header[3]]) as usize;
    if length < 4 {
        return Err(anyhow!("invalid TPKT length: {length}"));
    }
    let mut packet = vec![0u8; length];
    packet[..4].copy_from_slice(&header);
    stream.read_exact(&mut packet[4..]).await?;
    Ok(packet)
}

async fn tls_connect(
    tcp: TcpStream,
    destination: &str,
    chain: Arc<Mutex<Vec<Vec<u8>>>>,
) -> Result<tokio_rustls::client::TlsStream<TcpStream>> {
    let provider = Arc::new(ring::default_provider());
    let client_config = ClientConfig::builder_with_provider(provider)
        .with_safe_default_protocol_versions()?
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(CaptureCerts { chain }))
        .with_no_client_auth();

    let server_name = server_name_for(destination)?;

    let connector = TlsConnector::from(Arc::new(client_config));
    let stream = tokio::time::timeout(Duration::from_secs(15), connector.connect(server_name, tcp))
        .await
        .context("timed out during the TLS handshake with the RDP server")?
        .context("TLS handshake with the RDP server failed")?;
    Ok(stream)
}

fn server_name_for(destination: &str) -> Result<ServerName<'static>> {
    if let Ok(addr) = destination.parse::<SocketAddr>() {
        return Ok(ServerName::IpAddress(addr.ip().into()));
    }
    let host = destination.split(':').next().unwrap_or(destination);
    ServerName::try_from(host.to_owned()).map_err(|e| anyhow!("invalid destination for TLS: {e}"))
}

async fn relay(
    ws: WebSocket,
    tls_stream: tokio_rustls::client::TlsStream<TcpStream>,
) -> Result<()> {
    let (mut tls_read, mut tls_write) = tokio::io::split(tls_stream);
    let (mut ws_sink, mut ws_stream) = ws.split();

    let mut tcp_buf = vec![0u8; 64 * 1024];

    loop {
        tokio::select! {
            message = ws_stream.next() => {
                match message {
                    Some(Ok(Message::Binary(bytes))) => {
                        tls_write.write_all(&bytes).await?;
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    Some(Ok(_)) => {}
                    Some(Err(error)) => return Err(anyhow!("websocket error: {error}")),
                }
            }
            read = tls_read.read(&mut tcp_buf) => {
                let n = read?;
                if n == 0 {
                    break;
                }
                ws_sink.send(Message::Binary(tcp_buf[..n].to_vec().into())).await?;
            }
        }
    }

    tls_write.shutdown().await?;
    Ok(())
}

#[derive(Debug)]
struct CaptureCerts {
    chain: Arc<Mutex<Vec<Vec<u8>>>>,
}

impl ServerCertVerifier for CaptureCerts {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> std::result::Result<ServerCertVerified, TlsError> {
        let mut chain = self.chain.lock().expect("chain lock");
        chain.push(end_entity.to_vec());
        for cert in intermediates {
            chain.push(cert.to_vec());
        }
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, TlsError> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, TlsError> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        ring::default_provider()
            .signature_verification_algorithms
            .supported_schemes()
    }
}
