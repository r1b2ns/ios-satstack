import Foundation

/// Utility for logging HTTP requests as curl commands using `os.Logger`.
enum PrintProtocol {

    /// Logs the request as a curl command at `info` level.
    static func log(_ request: URLRequest) {
        request.curl()
    }

    /// Logs response data for a given scope and URL at `info` level.
    static func logDebugData(scope: String, url: String?, data: Data?) {
        Log.print.info("🔬 DEBUG MODE ON FOR: \(scope)")
        Log.print.info("📡 URL: \(url ?? "No URL passed")")
        Log.print.info("\(data?.debugString ?? "No Data passed")")
    }
}

// MARK: - URLRequest curl logging

private extension URLRequest {
    func curl() {
        guard let url = self.url else {
            Log.print.warning("⚠️ URLRequest has no URL")
            return
        }

        var baseCommand = #"curl "\#(url.absoluteString)""#
        if self.httpMethod == "HEAD" {
            baseCommand += " --head"
        }

        var command = [baseCommand]
        if let method = self.httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }

        if let headers = self.allHTTPHeaderFields {
            for (key, value) in headers where key != "Cookie" {
                command.append("-H '\(key): \(value)'")
            }
        }

        if let data = self.httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }

        let curlCommand = command.joined(separator: " \\\n\t")
        Log.print.info("📡 \(curlCommand)")
    }
}

// MARK: - Data debug helpers

private extension Data {
    var debugString: String {
        String(data: self, encoding: .utf8)?.replacingOccurrences(of: "\\/", with: "/") ?? "Unable to decode data"
    }
}
