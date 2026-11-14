use std::net::IpAddr;
use std::path::Path;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result};
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use rcgen::{
    BasicConstraints, Certificate, CertificateParams, CidrSubnet, DistinguishedName, DnType,
    GeneralSubtree, IsCa, KeyPair, KeyUsagePurpose, NameConstraints,
};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};
use rustls::ServerConfig;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use time::OffsetDateTime;
use tokio_rustls::TlsAcceptor;

#[derive(Clone)]
pub struct WebTls {
    pub acceptor: TlsAcceptor,
    pub trust: Arc<TrustInfo>,
}

pub struct TrustInfo {
    pub host: String,
    pub fingerprint: String,
    pub ca_der: Vec<u8>,
    pub ca_pem: String,
}

#[derive(Serialize, Deserialize, PartialEq)]
struct CertificateMetadata {
    sans: Vec<String>,
    expires: i64,
}

pub fn load_or_create(config_dir: &Path) -> Result<WebTls> {
    let directory = config_dir.join("tls");
    std::fs::create_dir_all(&directory)
        .with_context(|| format!("create {}", directory.display()))?;
    let host = std::env::var("COMPUTERNAME")
        .ok()
        .filter(|name| !name.is_empty())
        .unwrap_or_else(|| "pageway".to_owned());
    let sans = subject_alt_names(&host);

    let ca_path = directory.join("ca-cert.pem");
    let ca_key_path = directory.join("ca-key.pem");
    let ca_pem = match std::fs::read_to_string(&ca_path) {
        Ok(pem) => pem,
        Err(_) => {
            let (pem, key) = create_ca(&host)?;
            std::fs::write(&ca_path, &pem)?;
            std::fs::write(&ca_key_path, key)?;
            pem
        }
    };
    let ca_key_pem = std::fs::read_to_string(&ca_key_path).context("read CA private key")?;
    let ca_key = KeyPair::from_pem(&ca_key_pem).context("parse CA private key")?;
    let ca_params = CertificateParams::from_ca_cert_pem(&ca_pem).context("parse CA certificate")?;
    let ca = ca_params
        .self_signed(&ca_key)
        .context("load CA certificate")?;
    let ca_der = load_certs(&ca_path)?
        .into_iter()
        .next()
        .context("CA certificate missing")?
        .to_vec();

    let metadata_path = directory.join("server.json");
    let cert_path = directory.join("server-cert.pem");
    let key_path = directory.join("server-key.pem");
    let metadata = std::fs::read_to_string(&metadata_path)
        .ok()
        .and_then(|text| serde_json::from_str::<CertificateMetadata>(&text).ok());
    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
    let reusable = metadata.as_ref().is_some_and(|meta| {
        meta.sans == sans
            && meta.expires > now + 30 * 86400
            && cert_path.is_file()
            && key_path.is_file()
    });
    if !reusable {
        let (cert, key, expires) = create_server_certificate(&host, &sans, &ca, &ca_key)?;
        std::fs::write(&cert_path, cert)?;
        std::fs::write(&key_path, key)?;
        std::fs::write(
            &metadata_path,
            serde_json::to_vec(&CertificateMetadata { sans, expires })?,
        )?;
        tracing::info!(%host, "Generated a new Pageway RDP HTTPS certificate");
    }

    let certs = load_certs(&cert_path)?;
    let key = load_key(&key_path)?;
    let config =
        ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
            .with_safe_default_protocol_versions()?
            .with_no_client_auth()
            .with_single_cert(certs, key)?;
    let fingerprint = Sha256::digest(&ca_der)
        .iter()
        .map(|byte| format!("{byte:02X}"))
        .collect::<Vec<_>>()
        .join(":");

    Ok(WebTls {
        acceptor: TlsAcceptor::from(Arc::new(config)),
        trust: Arc::new(TrustInfo {
            host,
            fingerprint,
            ca_der,
            ca_pem,
        }),
    })
}

fn subject_alt_names(host: &str) -> Vec<String> {
    let mut names = vec![
        "localhost".to_owned(),
        "127.0.0.1".to_owned(),
        "::1".to_owned(),
    ];
    if host
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '.')
    {
        names.push(host.to_ascii_lowercase());
        names.push(format!("{}.local", host.to_ascii_lowercase()));
    }
    if let Ok(interfaces) = local_ip_address::list_afinet_netifas() {
        for (_, ip) in interfaces {
            if is_allowed_ip(ip) {
                names.push(ip.to_string());
            }
        }
    }
    names.sort();
    names.dedup();
    names
}

fn is_allowed_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => {
            ip.is_private()
                || ip.is_loopback()
                || ip.is_link_local()
                || (ip.octets()[0] == 100 && (64..128).contains(&ip.octets()[1]))
        }
        IpAddr::V6(ip) => {
            ip.is_loopback()
                || (ip.segments()[0] & 0xfe00) == 0xfc00
                || (ip.segments()[0] & 0xffc0) == 0xfe80
        }
    }
}

fn create_ca(host: &str) -> Result<(String, String)> {
    let mut params = CertificateParams::new(Vec::<String>::new())?;
    params.is_ca = IsCa::Ca(BasicConstraints::Constrained(0));
    params.distinguished_name = distinguished_name(&format!("Pageway RDP {host} Local CA"));
    params.key_usages = vec![KeyUsagePurpose::KeyCertSign, KeyUsagePurpose::CrlSign];
    params.not_before = OffsetDateTime::now_utc() - time::Duration::days(1);
    params.not_after = OffsetDateTime::now_utc() + time::Duration::days(3650);
    let permitted_dns = [
        "localhost".to_owned(),
        host.to_ascii_lowercase(),
        format!("{}.local", host.to_ascii_lowercase()),
    ];
    let mut permitted = permitted_dns
        .into_iter()
        .map(GeneralSubtree::DnsName)
        .collect::<Vec<_>>();
    for network in [
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "100.64.0.0/10",
        "fc00::/7",
        "fe80::/10",
        "::1/128",
    ] {
        let (address, prefix) = network.split_once('/').context("invalid private network")?;
        permitted.push(GeneralSubtree::IpAddress(CidrSubnet::from_addr_prefix(
            address.parse()?,
            prefix.parse()?,
        )));
    }
    params.name_constraints = Some(NameConstraints {
        permitted_subtrees: permitted,
        excluded_subtrees: Vec::new(),
    });
    let key = KeyPair::generate()?;
    let cert = params.self_signed(&key)?;
    Ok((cert.pem(), key.serialize_pem()))
}

fn create_server_certificate(
    host: &str,
    sans: &[String],
    ca: &Certificate,
    ca_key: &KeyPair,
) -> Result<(String, String, i64)> {
    let mut params = CertificateParams::new(sans.to_vec())?;
    params.distinguished_name = distinguished_name(&format!("Pageway RDP {host}"));
    params.use_authority_key_identifier_extension = true;
    params.key_usages = vec![
        KeyUsagePurpose::DigitalSignature,
        KeyUsagePurpose::KeyEncipherment,
    ];
    params.not_before = OffsetDateTime::now_utc() - time::Duration::days(1);
    params.not_after = OffsetDateTime::now_utc() + time::Duration::days(825);
    let expires = params.not_after.unix_timestamp();
    let key = KeyPair::generate()?;
    let cert = params.signed_by(&key, ca, ca_key)?;
    Ok((cert.pem(), key.serialize_pem(), expires))
}

fn distinguished_name(name: &str) -> DistinguishedName {
    let mut name_value = DistinguishedName::new();
    name_value.push(DnType::CommonName, name);
    name_value.push(DnType::OrganizationName, "Pageway");
    name_value
}

fn load_certs(path: &Path) -> Result<Vec<CertificateDer<'static>>> {
    let file = std::fs::File::open(path)?;
    rustls_pemfile::certs(&mut std::io::BufReader::new(file))
        .collect::<std::result::Result<Vec<_>, _>>()
        .context("read HTTPS certificate")
}

fn load_key(path: &Path) -> Result<PrivateKeyDer<'static>> {
    let file = std::fs::File::open(path)?;
    let mut reader = std::io::BufReader::new(file);
    let mut keys = rustls_pemfile::pkcs8_private_keys(&mut reader);
    let key = keys.next().context("HTTPS private key is missing")??;
    Ok(PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(key)))
}

impl TrustInfo {
    pub fn mobileconfig(&self) -> String {
        let uuid = self.fingerprint.replace(':', "");
        let uuid = format!(
            "{}-{}-{}-{}-{}",
            &uuid[0..8],
            &uuid[8..12],
            &uuid[12..16],
            &uuid[16..20],
            &uuid[20..32]
        );
        let host = xml_escape(&self.host);
        format!(
            r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>PayloadContent</key><array><dict>
<key>PayloadCertificateFileName</key><string>Pageway-RDP-{host}.cer</string>
<key>PayloadContent</key><data>{}</data>
<key>PayloadDescription</key><string>Pageway RDP local CA</string>
<key>PayloadDisplayName</key><string>Pageway RDP {host}</string>
<key>PayloadIdentifier</key><string>local.pageway.rdp.{uuid}.certificate</string>
<key>PayloadType</key><string>com.apple.security.root</string>
<key>PayloadUUID</key><string>{uuid}</string>
<key>PayloadVersion</key><integer>1</integer>
</dict></array>
<key>PayloadDisplayName</key><string>Pageway RDP {host}</string>
<key>PayloadIdentifier</key><string>local.pageway.rdp.{uuid}</string>
<key>PayloadRemovalDisallowed</key><false/>
<key>PayloadType</key><string>Configuration</string>
<key>PayloadUUID</key><string>{uuid}</string>
<key>PayloadVersion</key><integer>1</integer>
</dict></plist>"#,
            BASE64.encode(&self.ca_der)
        )
    }

    pub fn windows_command(&self) -> String {
        let encoded = BASE64.encode(self.ca_pem.as_bytes());
        format!(
            "@echo off\r\nsetlocal\r\nset \"B64=%TEMP%\\pageway-rdp-ca-base64.txt\"\r\nset \"CERT=%TEMP%\\pageway-rdp-ca.cer\"\r\n> \"%B64%\" echo {encoded}\r\ncertutil.exe -decode \"%B64%\" \"%CERT%\"\r\nif errorlevel 1 goto failed\r\ncertutil.exe -user -addstore Root \"%CERT%\"\r\nif errorlevel 1 goto failed\r\ndel \"%B64%\" \"%CERT%\"\r\necho.\r\necho Pageway RDP certificate installed. Return to the Pageway RDP tab.\r\npause\r\nexit /b 0\r\n:failed\r\necho Certificate import failed. Download the CER file and use Windows certificate import instead.\r\npause\r\nexit /b 1\r\n"
        )
    }
}

fn xml_escape(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn private_and_tailscale_addresses_are_allowed() {
        assert!(is_allowed_ip("192.168.20.177".parse().unwrap()));
        assert!(is_allowed_ip("100.100.1.2".parse().unwrap()));
        assert!(!is_allowed_ip("8.8.8.8".parse().unwrap()));
    }

    #[test]
    fn certificate_directory_is_reused() {
        let directory =
            std::env::temp_dir().join(format!("pageway-tls-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&directory);
        let first = load_or_create(&directory).unwrap();
        let second = load_or_create(&directory).unwrap();
        assert_eq!(first.trust.fingerprint, second.trust.fingerprint);
        assert!(!first.trust.windows_command().is_empty());
        assert!(first
            .trust
            .mobileconfig()
            .contains("com.apple.security.root"));
        std::fs::remove_dir_all(directory).unwrap();
    }
}
