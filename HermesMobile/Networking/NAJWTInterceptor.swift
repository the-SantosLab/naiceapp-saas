import Foundation

/// Automatically adds JWT Authorization header to all requests
/// to the configured nAIce SaaS server. No changes needed in any API files.
final class NAJWTInterceptor: URLProtocol, URLSessionDelegate {
    static var enabled = false

    /// Call once on app launch to install the interceptor
    static func install() {
        URLProtocol.registerClass(self)
        enabled = true
    }

    static func uninstall() {
        URLProtocol.unregisterClass(self)
        enabled = false
    }

    // Only intercept requests to the SaaS server
    override class func canInit(with request: URLRequest) -> Bool {
        guard enabled, let host = request.url?.host else { return false }
        let serverHost = URL(string: NASaaSAuth.shared.serverURL)?.host ?? ""
        return host == serverHost
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let client = client else { return }

        // Create a new request with the JWT token added
        var newReq = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        // Get token safely
        let token = NASaaSAuth.shared.token

        if let token = token {
            newReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Use URLSession to perform the actual request
        let config = URLSessionConfiguration.default
        // Prevent infinite loop by not using our protocol for the internal request
        let protoClasses = config.protocolClasses ?? []
        config.protocolClasses = protoClasses.filter { $0 != NAJWTInterceptor.self }

        let session = URLSession(configuration: config)
        let task = session.dataTask(with: newReq as URLRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                client.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response = response {
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = data {
                client.urlProtocol(self, didLoad: data)
            }
            client.urlProtocolDidFinishLoading(self)
        }
        task.resume()
    }

    override func stopLoading() {
        // Nothing to clean up
    }
}