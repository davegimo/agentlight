import Foundation
import Network

struct ServerConfig: Codable {
    let port: UInt16
    let socketPath: String

    enum CodingKeys: String, CodingKey {
        case port
        case socketPath = "socket_path"
    }
}

struct ApprovalRespondRequest: Codable {
    let id: String
    let decision: ApprovalDecision?
}

final class EventServer: @unchecked Sendable {
    static let defaultPort: UInt16 = 47_831

    private let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.agentlight.eventserver", qos: .userInitiated)
    private let onEvent: @Sendable (AgentEvent) -> Void

    init(port: UInt16 = EventServer.defaultPort, onEvent: @escaping @Sendable (AgentEvent) -> Void) {
        self.port = port
        self.onEvent = onEvent
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.acceptLocalOnly = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw EventServerError.invalidPort
        }

        let listener = try NWListener(using: parameters, on: nwPort)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }

        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                NSLog("AgentLight: event server failed — \(error.localizedDescription)")
            }
        }

        listener.start(queue: queue)
        try writeConfig()
        NSLog("AgentLight: event server listening on port \(port)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                NSLog("AgentLight: connection error — \(error.localizedDescription)")
                connection.cancel()
                return
            }

            var accumulated = buffer
            if let data {
                accumulated.append(data)
            }

            if self.isRequestComplete(accumulated) || isComplete {
                self.processRequest(accumulated, connection: connection)
            } else {
                self.receive(on: connection, buffer: accumulated)
            }
        }
    }

    private func isRequestComplete(_ data: Data) -> Bool {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else {
            return false
        }

        guard let headerString = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else {
            return false
        }

        let contentLength = headerString
            .components(separatedBy: "\r\n")
            .compactMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2,
                      parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else {
                    return nil
                }
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
            .first ?? 0

        let bodyStart = headerEnd.upperBound
        let bodyReceived = data.count - bodyStart
        return bodyReceived >= contentLength
    }

    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"invalid request\"}")
            return
        }

        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"empty request\"}")
            return
        }

        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"malformed request\"}")
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        if method == "GET", path == "/health" || path == "/health/" {
            sendResponse(connection: connection, status: "200 OK", body: "{\"status\":\"ok\"}")
            return
        }

        guard method == "POST" else {
            sendResponse(connection: connection, status: "404 Not Found", body: "{\"error\":\"not found\"}")
            return
        }

        guard let bodyStart = request.range(of: "\r\n\r\n") else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"missing body\"}")
            return
        }

        let bodyString = String(request[bodyStart.upperBound...])
        guard let bodyData = bodyString.data(using: .utf8) else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"invalid body\"}")
            return
        }

        switch path {
        case "/event", "/event/":
            handleEvent(bodyData, connection: connection)
        case "/approval/pending", "/approval/pending/":
            handleApprovalPending(bodyData, connection: connection)
        case "/approval/respond", "/approval/respond/":
            handleApprovalRespond(bodyData, connection: connection)
        default:
            sendResponse(connection: connection, status: "404 Not Found", body: "{\"error\":\"not found\"}")
        }
    }

    private func handleEvent(_ bodyData: Data, connection: NWConnection) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: value) {
                return date
            }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fallback.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }

        do {
            let event = try decoder.decode(AgentEvent.self, from: bodyData)
            onEvent(event)
            sendResponse(connection: connection, status: "200 OK", body: "{\"status\":\"ok\"}")
        } catch {
            NSLog("AgentLight: failed to decode event — \(error.localizedDescription)")
            sendResponse(connection: connection, status: "422 Unprocessable Entity", body: "{\"error\":\"invalid event\"}")
        }
    }

    private func handleApprovalPending(_ bodyData: Data, connection: NWConnection) {
        let decoder = JSONDecoder()
        do {
            let request = try decoder.decode(ApprovalRequest.self, from: bodyData)
            let pending = ApprovalManager.shared.register(request: request)
            let body = "{\"status\":\"ok\",\"id\":\"\(pending.id)\"}"
            sendResponse(connection: connection, status: "200 OK", body: body)
        } catch {
            sendResponse(connection: connection, status: "422 Unprocessable Entity", body: "{\"error\":\"invalid approval request\"}")
        }
    }

    private func handleApprovalRespond(_ bodyData: Data, connection: NWConnection) {
        let decoder = JSONDecoder()
        do {
            let request = try decoder.decode(ApprovalRespondRequest.self, from: bodyData)
            ApprovalManager.shared.dismiss(id: request.id)
            sendResponse(connection: connection, status: "200 OK", body: "{\"status\":\"ok\"}")
        } catch {
            sendResponse(connection: connection, status: "422 Unprocessable Entity", body: "{\"error\":\"invalid respond request\"}")
        }
    }

    private func sendResponse(connection: NWConnection, status: String, body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func writeConfig() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AgentLight", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let config = ServerConfig(port: port, socketPath: dir.appendingPathComponent("agentlight.sock").path)
        let data = try JSONEncoder().encode(config)
        try data.write(to: dir.appendingPathComponent("server.json"), options: .atomic)
    }

    static var configDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AgentLight", isDirectory: true)
    }
}

enum EventServerError: Error {
    case invalidPort
}
