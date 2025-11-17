# Chat UI Swift

A SwiftUI chat application showcasing 
[swift-huggingface](https://github.com/mattt/swift-huggingface) and 
[AnyLanguageModel](https://github.com/mattt/AnyLanguageModel).

<video src="https://github.com/user-attachments/assets/5adc7592-a101-4c57-b82f-2f6a26ef350a" controls muted loop>
  <p>Demo of Chat UI Swift showing conversations with Apple Intelligence and Hugging Face models</p>
</video>

> [!NOTE] 
> This project is in active development. 
> Features and APIs may change.

## Features

- [x] **Apple Intelligence** — Native integration with Apple Foundation Models (macOS 26+) for on-device AI
- [x] **Hugging Face Integration** — Connect to Hugging Face with OAuth 2.0 authentication
- [x] **Streaming Responses** — Real-time streaming of AI responses for a responsive user experience
- [x] **Chat Persistence** — Save and manage multiple conversations
- [ ] **MLX Model Support** — Download and run models locally using MLX
- [ ] **CoreML Integration** — Support for CoreML-optimized models
- [ ] **GGUF Format Support** — Load GGUF models from Hugging Face Hub
- [ ] **Model Downloads** — Browse and download models directly from Hugging Face
- [ ] **BYOK** — Bring your own API keys for other inference providers (OpenAI, Anthropic, etc.)

## Getting Started

### Prerequisites

- macOS 26 or later
- Xcode 26+

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/mattt/chat-ui-swift.git
cd chat-ui-swift
```

2. **Open in Xcode**

```bash
xed .
```

3. **Build and run**

Press <kbd>⌘</kbd><kbd>R</kbd> to build and run the application.

### Using Hugging Face Models

To use Hugging Face's Inference API:

1. Launch the app
2. Click the sign-in button in the sidebar
3. Authenticate with your Hugging Face account
4. Select a Hugging Face model from the model picker
5. Start chatting!

The app uses OAuth 2.0 to securely authenticate with Hugging Face. 
Your access token is stored securely in the Keychain and automatically refreshed when needed.

## Related Projects

- https://github.com/huggingface/swift-chat
- https://github.com/huggingface/chat-ui

## License

This project is available under the MIT license. 
See the LICENSE file for more info.

## Legal

Hugging Face® is a registered trademark of Hugging Face, Inc.
