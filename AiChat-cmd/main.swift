//
//  main.swift
//  AiChat-cmd
//
//  Created by 程宁 on 2024/11/3.
//

import Foundation

// 配置参数
let appID = "4b23ba70-14f8-4798-92c6-3fbaf26eefce"
let authFilePath = FileManager.default.currentDirectoryPath + "/auth.txt"
let conversationFilePath = FileManager.default.currentDirectoryPath + "/conversation_id.txt"

struct ChatItem: Identifiable {
    let id = UUID()
    let datetime: String
    let issue: String
    let answer: String?
    let isResponse: Bool
    let model: String
}

// 读取或保存授权信息
func getAuthorization() -> String? {
    if let auth = try? String(contentsOfFile: authFilePath).trimmingCharacters(in: .whitespacesAndNewlines), !auth.isEmpty {
        return auth
    } else {
        print("Authorization key is missing. Please save it in auth.txt in the current directory.")
        return nil
    }
}

// 读取或保存 conversation_id
func saveConversationID(_ conversationID: String) {
    try? conversationID.write(toFile: conversationFilePath, atomically: true, encoding: .utf8)
}

func getConversationID() -> String {
    (try? String(contentsOfFile: conversationFilePath).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
}

// 创建并保存 conversation_id
func createAndSaveConversationID() {
    guard let url = URL(string: "https://qianfan.baidubce.com/v2/app/conversation"),
          let authorization = getAuthorization() else { return }
    
    let body: [String: Any] = ["app_id": appID]
    guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
        print("Invalid JSON format")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
    request.httpBody = jsonData
    
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { dispatchGroup.leave() }
        
        if let error = error {
            print("Request failed with error: \(error.localizedDescription)")
            return
        }
        
        guard let data = data else {
            print("No data received")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let conversationID = json["conversation_id"] as? String {
                saveConversationID(conversationID)
                print("Conversation ID saved: \(conversationID)")
            } else {
                print("Invalid response format")
            }
        } catch {
            print("Failed to parse JSON: \(error.localizedDescription)")
        }
    }.resume()
    
    dispatchGroup.wait()
}

// 发送消息
func sendMessage(query: String) {
    guard let url = URL(string: "https://qianfan.baidubce.com/v2/app/conversation/runs"),
          let authorization = getAuthorization() else { return }
    
    let conversationID = getConversationID()
    
    let body: [String: Any] = [
        "app_id": appID,
        "query": query,
        "stream": false,
        "conversation_id": conversationID
    ]
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
        print("Invalid JSON format")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
    request.httpBody = jsonData
    
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { dispatchGroup.leave() }
        
        if let error = error {
            print("Request failed with error: \(error.localizedDescription)")
            return
        }
        
        guard let data = data else {
            print("No data received")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let answer = json["answer"] as? String,
               let datetime = json["date"] as? String {
                
                let chatItem = ChatItem(
                    datetime: datetime,
                    issue: query,
                    answer: answer,
                    isResponse: true,
                    model: "gpt-3.5-turbo"
                )
                
                print("Response:")
                print("Date: \(chatItem.datetime)")
                print("Q: \(chatItem.issue)")
                print("A: \(chatItem.answer ?? "No answer")")
            } else {
                print("Invalid response format")
            }
        } catch {
            print("Failed to parse JSON: \(error.localizedDescription)")
        }
    }.resume()
    
    dispatchGroup.wait()
}

// 运行命令行应用
if CommandLine.arguments.count > 1 {
    let command = CommandLine.arguments[1]
    
    switch command {
    case "start":
        createAndSaveConversationID()
    case "send":
        if CommandLine.arguments.count > 2 {
            let query = CommandLine.arguments[2]
            sendMessage(query: query)
        } else {
            print("Please provide a query after 'send'")
        }
    default:
        print("Unknown command. Use 'start' to create a conversation or 'send <query>' to send a message.")
    }
} else {
    print("Usage:")
    print("  start          - Create and save a new conversation ID")
    print("  send <query>   - Send a message with the saved conversation ID")
}

