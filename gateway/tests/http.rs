use std::fs;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

struct TestGateway {
    child: Child,
    address: String,
    static_dir: PathBuf,
}

impl TestGateway {
    fn start() -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind test port");
        let address = listener
            .local_addr()
            .expect("read test address")
            .to_string();
        drop(listener);

        let unique = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("read clock")
            .as_nanos();
        let static_dir =
            std::env::temp_dir().join(format!("pageway-http-test-{}-{unique}", std::process::id()));
        fs::create_dir_all(&static_dir).expect("create static directory");
        fs::write(static_dir.join("index.html"), "Pageway").expect("write login page");

        let child = Command::new(env!("CARGO_BIN_EXE_pageway-rdp"))
            .args(["--listen", &address, "--static"])
            .arg(&static_dir)
            .arg("--cert-dir")
            .arg(&static_dir)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .expect("start gateway");
        let gateway = Self {
            child,
            address,
            static_dir,
        };

        let deadline = Instant::now() + Duration::from_secs(10);
        while TcpStream::connect(&gateway.address).is_err() {
            assert!(Instant::now() < deadline, "gateway did not start");
            thread::sleep(Duration::from_millis(50));
        }
        gateway
    }

    fn response(&self, path: &str) -> Vec<u8> {
        let mut stream = TcpStream::connect(&self.address).expect("connect to gateway");
        write!(
            stream,
            "GET {path} HTTP/1.1\r\nHost: {}\r\nConnection: close\r\n\r\n",
            self.address
        )
        .expect("write HTTP request");
        let mut response = Vec::new();
        stream.read_to_end(&mut response).expect("read response");
        response
    }

    fn status_code(&self, path: &str) -> u16 {
        let response = self.response(path);
        String::from_utf8_lossy(&response)
            .split_whitespace()
            .nth(1)
            .expect("read HTTP status")
            .parse()
            .expect("parse HTTP status")
    }
}

impl Drop for TestGateway {
    fn drop(&mut self) {
        self.child.kill().expect("stop gateway");
        self.child.wait().expect("wait for gateway");
        fs::remove_dir_all(&self.static_dir).expect("remove static directory");
    }
}

// oracle: mutant retaining the removed admin API or breaking the static login page
#[test]
fn serves_login_without_admin_api() {
    let gateway = TestGateway::start();

    assert_eq!(gateway.status_code("/admin/api/config"), 404);
    assert_eq!(gateway.status_code("/"), 200);
    assert_eq!(gateway.status_code("/pageway/ping"), 204);
    assert_eq!(gateway.status_code("/pageway/ca.der"), 200);
    let der_response = gateway.response("/pageway/ca.der");
    let der_headers = String::from_utf8_lossy(&der_response).to_ascii_lowercase();
    assert!(der_headers.contains("content-type: application/x-x509-ca-cert"));
    assert!(!der_headers.contains("content-disposition:"));
}
