# Shiny app template for the AI agent
# This runs as a background job in RStudio

cat("Starting Rflow Shiny app...\n")

tryCatch({
  suppressPackageStartupMessages({
    library(shiny)
    library(bslib)
    library(ellmer)
    library(shinychat)
    library(coro)
    library(later)
    library(shinyjs)
    # Rflow package not needed - tools are pre-loaded in client
    cat("Note: Rflow package not installed, using loaded functions\n")
  })
  cat("Libraries loaded successfully\n")
}, error = function(e) {
  cat("Error loading libraries:", conditionMessage(e), "\n")
  stop(e)
})

working_dir <- '{{working_dir}}'
cat("Working directory:", working_dir, "\n")

client <- readRDS('{{client_path}}')
cat("Client loaded (with tools already set)\n")

# Tools are already set in the client object when it was created
# No need to call set_tools() again

cat("Creating UI...\n")

# Custom modern UI
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
      
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }
      
      /* Clean Professional Theme - No Gradients */
      :root {
        --primary: #0066FF;
        --primary-hover: #0052CC;
        --bg-primary: #FFFFFF;
        --bg-secondary: #F7F8FA;
        --bg-tertiary: #FAFBFC;
        --bg-hover: #F0F1F3;
        --text-primary: #1A1A1A;
        --text-secondary: #6B7280;
        --text-tertiary: #9CA3AF;
        --border-color: #E5E7EB;
        --border-light: #F3F4F6;
        --message-user-bg: #0066FF;
        --message-assistant-bg: #F7F8FA;
        --sidebar-bg: #FAFBFC;
        --input-bg: #FFFFFF;
        --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
        --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07);
        --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1);
        --success: #10B981;
        --error: #EF4444;
        --warning: #F59E0B;
      }

      /* Dark mode */
      .dark-mode {
        --primary: #3B82F6;
        --primary-hover: #2563EB;
        --bg-primary: #0F1419;
        --bg-secondary: #1A1F2E;
        --bg-tertiary: #0F1419;
        --bg-hover: #252A35;
        --text-primary: #E5E7EB;
        --text-secondary: #9CA3AF;
        --text-tertiary: #6B7280;
        --border-color: #2D3748;
        --border-light: #1F2937;
        --message-user-bg: #3B82F6;
        --message-assistant-bg: #1A1F2E;
        --sidebar-bg: #1A1F2E;
        --input-bg: #0F1419;
        --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.3);
        --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.4);
        --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.5);
      }
      
      html, body {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        background: var(--bg-tertiary);
        overflow: hidden;
        height: 100%;
        width: 100%;
        transition: background 0.3s ease;
      }
      
      /* Prevent Shiny's gray overlay during processing */
      .shiny-busy-overlay {
        display: none !important;
      }
      
      /* Keep UI fully visible during processing */
      .recalculating {
        opacity: 1 !important;
      }
      
      .container-fluid {
        padding: 0 !important;
        height: 100vh;
        width: 100%;
      }
      
      .main-container {
        display: flex;
        flex-direction: row;
        height: 100vh;
        background: var(--bg-primary);
        box-shadow: 0 0 20px var(--shadow-md);
        transition: background 0.3s ease;
      }
      
      /* Sidebar for chat history */
      .sidebar {
        width: 260px;
        background: var(--sidebar-bg);
        border-right: 1px solid var(--border-color);
        display: flex;
        flex-direction: column;
        overflow: hidden;
        transition: all 0.3s ease;
      }
      
      .sidebar.collapsed {
        width: 0;
        border-right: none;
      }
      
      .sidebar-header {
        padding: 20px;
        border-bottom: 1px solid var(--border-color);
      }
      
      .new-chat-btn {
        width: 100%;
        padding: 10px 16px;
        background: var(--primary);
        color: white;
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        transition: all 0.15s ease;
      }

      .new-chat-btn:hover {
        background: var(--primary-hover);
        transform: translateY(-1px);
        box-shadow: var(--shadow-sm);
      }
      
      .workspace-btn {
        flex: 1;
        padding: 8px;
        background: var(--bg-secondary);
        border: 1px solid var(--border-color);
        border-radius: 6px;
        font-size: 16px;
        cursor: pointer;
        transition: all 0.2s;
      }
      
      .workspace-btn:hover {
        background: var(--border-light);
        border-color: #6366f1;
      }
      
      .workspace-info {
        margin-top: 10px;
        padding: 10px;
        background: var(--bg-secondary);
        border-radius: 6px;
        font-size: 11px;
        color: var(--text-secondary);
      }
      
      .workspace-info .folder-name {
        font-weight: 600;
        color: var(--text-primary);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      
      .workspace-info .file-count {
        margin-top: 4px;
        opacity: 0.8;
      }
      
      .chat-history {
        flex: 1;
        overflow-y: auto;
        padding: 10px;
      }
      
      .chat-history-item {
        padding: 12px;
        margin-bottom: 4px;
        border-radius: 6px;
        cursor: pointer;
        font-size: 13px;
        color: var(--text-primary);
        transition: all 0.2s;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      
      .chat-history-item:hover {
        background: var(--border-light);
      }
      
      .chat-history-item.active {
        background: var(--bg-hover);
        color: var(--primary);
        font-weight: 500;
        border-left: 2px solid var(--primary);
      }
      
      /* Main chat area */
      .chat-container {
        flex: 1;
        display: flex;
        flex-direction: column;
        height: 100vh;
      }
      
      /* Header - Clean & Professional */
      .app-header {
        background: var(--bg-primary);
        color: var(--text-primary);
        padding: 14px 20px;
        border-bottom: 1px solid var(--border-color);
        position: relative;
        z-index: 10;
        flex-shrink: 0;
        display: flex;
        align-items: center;
        gap: 12px;
      }
      
      .sidebar-toggle {
        background: var(--bg-secondary);
        border: 1px solid var(--border-color);
        color: var(--text-primary);
        width: 36px;
        height: 36px;
        border-radius: 6px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.15s ease;
        flex-shrink: 0;
      }

      .sidebar-toggle:hover {
        background: var(--bg-hover);
        border-color: var(--primary);
        color: var(--primary);
        transform: translateY(-1px);
        box-shadow: var(--shadow-sm);
      }
      
      .sidebar-toggle svg {
        width: 20px;
        height: 20px;
      }
      
      .header-content {
        flex: 1;
      }
      
      .app-header h1 {
        font-size: 18px;
        font-weight: 600;
        margin: 0;
        letter-spacing: -0.3px;
        color: var(--text-primary);
      }

      .header-subtitle {
        font-size: 13px;
        margin: 2px 0 0 0;
        color: var(--text-secondary);
        font-weight: 400;
      }
      
      /* Chat Area */
      .chat-area {
        flex: 1;
        display: flex;
        flex-direction: column;
        background: var(--bg-primary);
        position: relative;
        min-height: 0;
        overflow: hidden;
        transition: background 0.3s ease;
      }
      
      .messages-container {
        flex: 1;
        overflow-y: auto;
        overflow-x: hidden;
        padding: 20px;
        background: var(--bg-tertiary);
        min-height: 0;
        transition: background 0.3s ease;
      }
      
      .message {
        margin-bottom: 20px;
        animation: fadeInUp 0.3s ease-out;
        position: relative;
      }

      @keyframes fadeInUp {
        from {
          opacity: 0;
          transform: translateY(15px);
        }
        to {
          opacity: 1;
          transform: translateY(0);
        }
      }

      /* Message timestamp */
      .message-timestamp {
        font-size: 11px;
        color: var(--text-tertiary);
        margin-top: 4px;
        opacity: 0.7;
        font-weight: 400;
      }

      .message:hover .message-timestamp {
        opacity: 1;
      }
      
      .message-user {
        display: flex;
        justify-content: flex-end;
      }
      
      .message-user .message-content {
        background: var(--message-user-bg);
        color: white;
        padding: 12px 18px;
        border-radius: 12px 12px 2px 12px;
        max-width: 75%;
        box-shadow: var(--shadow-sm);
        font-size: 14.5px;
        line-height: 1.5;
        word-wrap: break-word;
        overflow-wrap: break-word;
      }
      
      .message-assistant {
        display: flex;
        justify-content: flex-start;
        align-items: flex-start;
        gap: 12px;
      }
      
      .message-avatar {
        width: 32px;
        height: 32px;
        border-radius: 50%;
        background: var(--primary);
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-weight: 500;
        font-size: 16px;
        flex-shrink: 0;
        box-shadow: 0 2px 8px rgba(102, 126, 234, 0.2);
        position: relative;
      }

      /* Pulsing avatar animation for thinking state */
      .message-avatar.thinking {
        animation: avatarPulse 2s ease-in-out infinite;
      }

      .message-avatar.thinking::before {
        content: '';
        position: absolute;
        top: -4px;
        left: -4px;
        right: -4px;
        bottom: -4px;
        border-radius: 50%;
        border: 2px solid var(--primary);
        opacity: 0;
        animation: ringPulse 2s ease-in-out infinite;
      }

      @keyframes avatarPulse {
        0%, 100% {
          transform: scale(1);
          box-shadow: 0 2px 8px rgba(102, 126, 234, 0.2);
        }
        50% {
          transform: scale(1.05);
          box-shadow: 0 4px 16px rgba(102, 126, 234, 0.4);
        }
      }

      @keyframes ringPulse {
        0% {
          transform: scale(1);
          opacity: 1;
        }
        100% {
          transform: scale(1.5);
          opacity: 0;
        }
      }

      /* Typing indicator dots */
      .typing-indicator {
        display: flex;
        gap: 4px;
        padding: 12px 18px;
      }

      .typing-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: var(--text-tertiary);
        animation: typingDot 1.4s ease-in-out infinite;
      }

      .typing-dot:nth-child(1) {
        animation-delay: 0s;
      }

      .typing-dot:nth-child(2) {
        animation-delay: 0.2s;
      }

      .typing-dot:nth-child(3) {
        animation-delay: 0.4s;
      }

      @keyframes typingDot {
        0%, 60%, 100% {
          transform: translateY(0);
          opacity: 0.4;
        }
        30% {
          transform: translateY(-8px);
          opacity: 1;
        }
      }

      .message-avatar svg {
        width: 20px;
        height: 20px;
      }
      
      .message-assistant .message-content {
        background: var(--message-assistant-bg);
        color: var(--text-primary);
        padding: 12px 18px;
        border-radius: 20px 20px 20px 4px;
        max-width: 75%;
        box-shadow: 0 2px 10px var(--shadow-sm);
        border: 1px solid var(--border-light);
        font-size: 14.5px;
        line-height: 1.6;
        word-wrap: break-word;
        overflow-wrap: break-word;
        overflow: visible;
        transition: all 0.3s ease;
      }
      
      /* Welcome message specific styling */
      .welcome-message {
        max-width: 90% !important;
        padding: 20px 24px !important;
        overflow: visible !important;
        white-space: normal !important;
        height: auto !important;
        min-height: fit-content !important;
      }
      
      .welcome-message ul {
        display: block !important;
        margin: 8px 0 !important;
        padding-left: 20px !important;
      }
      
      .welcome-message li {
        display: list-item !important;
        list-style-type: disc !important;
      }
      
      /* Quick Actions Bar - Show 4 buttons, scroll for more */
      .quick-actions-bar {
        display: flex;
        gap: 8px;
        padding: 12px 16px;
        background: var(--bg-secondary);
        border-top: 1px solid var(--border-light);
        overflow-x: auto;
        overflow-y: hidden;
        flex-shrink: 0;
        position: relative;
        scroll-behavior: smooth;
        scrollbar-width: thin;
        scrollbar-color: var(--border-color) transparent;
        /* Prevent flex from shrinking buttons to fit */
        flex-wrap: nowrap;
        width: 100%;
      }

      .quick-actions-bar::-webkit-scrollbar {
        height: 6px;
      }

      .quick-actions-bar::-webkit-scrollbar-track {
        background: transparent;
      }

      .quick-actions-bar::-webkit-scrollbar-thumb {
        background: var(--border-color);
        border-radius: 3px;
      }

      .quick-actions-bar::-webkit-scrollbar-thumb:hover {
        background: var(--text-secondary);
      }

      .quick-action-btn {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        padding: 8px 14px;
        background: var(--bg-primary);
        border: 1px solid var(--border-color);
        border-radius: 20px;
        font-size: 13px;
        font-weight: 500;
        color: var(--text-primary);
        cursor: pointer;
        transition: all 0.15s ease;
        white-space: nowrap;
        flex-shrink: 0;
        flex-grow: 0;
        min-width: fit-content;
      }

      .quick-action-btn span {
        white-space: nowrap;
        overflow: visible;
      }

      .quick-action-btn:hover {
        background: var(--bg-hover);
        border-color: var(--primary);
        color: var(--primary);
        transform: translateY(-1px);
        box-shadow: var(--shadow-sm);
      }

      .quick-action-btn svg {
        flex-shrink: 0;
      }

      /* Input Area */
      .input-area {
        padding: 12px 16px;
        background: var(--bg-primary);
        border-top: 1px solid var(--border-light);
        box-shadow: 0 -2px 12px var(--shadow-sm);
        flex-shrink: 0;
        transition: all 0.3s ease;
      }
      
      .input-wrapper {
        display: flex;
        gap: 8px;
        align-items: flex-end;
      }
      
      .input-controls {
        display: none;
      }
      
      .file-upload-btn {
        background: transparent;
        border: none;
        border-radius: 50%;
        padding: 8px;
        font-size: 0;
        color: #667eea;
        cursor: pointer;
        transition: all 0.2s ease;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 40px;
        height: 40px;
        position: relative;
      }
      
      .file-upload-btn .form-group {
        position: absolute;
        width: 1px;
        height: 1px;
        opacity: 0;
        overflow: hidden;
        z-index: -1;
      }
      
      /* File attachments preview */
      .file-attachments {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin-bottom: 8px;
      }
      
      .file-chip {
        background: var(--bg-secondary);
        border: 1px solid var(--border-light);
        border-radius: 8px;
        padding: 8px 12px;
        display: inline-flex;
        align-items: center;
        gap: 8px;
        font-size: 12px;
        color: var(--text-primary);
        transition: all 0.2s ease;
        max-width: 250px;
      }
      
      .file-chip:hover {
        background: var(--border-light);
      }
      
      .file-icon {
        width: 20px;
        height: 20px;
        flex-shrink: 0;
      }
      
      .file-info {
        flex: 1;
        min-width: 0;
      }
      
      .file-name {
        font-weight: 500;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        display: block;
      }
      
      .file-size {
        font-size: 10px;
        color: var(--text-secondary);
        display: block;
      }
      
      .file-chip-remove {
        cursor: pointer;
        color: #ef4444;
        font-weight: bold;
        font-size: 18px;
        line-height: 1;
        padding: 0 4px;
        border-radius: 4px;
        transition: all 0.2s;
        flex-shrink: 0;
      }
      
      .file-chip-remove:hover {
        background: #fee2e2;
        color: #dc2626;
      }
      
      .file-upload-btn:hover {
        background: rgba(102, 126, 234, 0.1);
      }
      
      .file-upload-btn svg {
        width: 20px;
        height: 20px;
      }
      
      .file-upload-btn input[type='file'] {
        display: none;
      }
      
      .message-input-container {
        flex: 1;
        position: relative;
      }
      
      .message-input-container .form-group {
        margin: 0;
      }
      
      .message-input-container label {
        display: none;
      }
      
      #messageInput,
      .message-input {
        width: 100% !important;
        padding: 10px 14px !important;
        border: 2px solid var(--border-light) !important;
        border-radius: 10px !important;
        font-size: 14px !important;
        font-family: inherit !important;
        resize: none !important;
        transition: all 0.2s ease !important;
        outline: none !important;
        min-height: 42px !important;
        max-height: 120px !important;
        background: var(--input-bg) !important;
        color: var(--text-primary) !important;
      }
      
      #messageInput:focus,
      .message-input:focus {
        border-color: var(--primary) !important;
        box-shadow: 0 0 0 3px rgba(0, 102, 255, 0.1) !important;
      }
      
      #messageInput::placeholder,
      .message-input::placeholder {
        color: #a0aec0 !important;
      }
      
      .send-btn {
        background: var(--primary);
        color: white;
        border: none;
        border-radius: 8px;
        padding: 10px 20px;
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.15s ease;
        box-shadow: var(--shadow-sm);
        min-width: 70px;
        height: 40px;
      }

      .send-btn:hover {
        background: var(--primary-hover);
        transform: translateY(-1px);
        box-shadow: var(--shadow-md);
      }

      .send-btn:active {
        transform: translateY(0);
      }

      .send-btn:disabled {
        opacity: 0.5;
        cursor: not-allowed;
        transform: none;
      }
      
      /* File attachments */
      .file-attachments {
        display: flex;
        gap: 6px;
        flex-wrap: wrap;
        margin-bottom: 8px;
      }
      
      .file-chip {
        background: #f0f4ff;
        border: 1px solid #d0d9ff;
        border-radius: 6px;
        padding: 4px 10px;
        font-size: 12px;
        color: #667eea;
        display: inline-flex;
        align-items: center;
        gap: 6px;
      }
      
      .file-chip-remove {
        cursor: pointer;
        color: #999;
        font-weight: bold;
        margin-left: 4px;
      }
      
      .file-chip-remove:hover {
        color: #666;
      }
      
      /* Progress Bar */
      .progress-bar-container {
        position: fixed;
        top: 60px;
        left: 50%;
        transform: translateX(-50%);
        background: var(--bg-primary);
        border: 1px solid var(--border-color);
        border-radius: 8px;
        padding: 12px 16px;
        box-shadow: var(--shadow-lg);
        z-index: 1000;
        min-width: 300px;
        animation: slideDown 0.3s ease-out;
      }

      @keyframes slideDown {
        from {
          opacity: 0;
          transform: translateX(-50%) translateY(-10px);
        }
        to {
          opacity: 1;
          transform: translateX(-50%) translateY(0);
        }
      }

      .progress-bar-text {
        font-size: 13px;
        color: var(--text-primary);
        margin-bottom: 8px;
        display: flex;
        align-items: center;
        gap: 8px;
      }

      .progress-bar-spinner {
        width: 14px;
        height: 14px;
        border: 2px solid var(--primary);
        border-top-color: transparent;
        border-radius: 50%;
        animation: spin-tool 0.8s linear infinite;
      }

      .progress-bar {
        height: 4px;
        background: var(--bg-secondary);
        border-radius: 2px;
        overflow: hidden;
      }

      .progress-bar-fill {
        height: 100%;
        background: var(--primary);
        border-radius: 2px;
        transition: width 0.3s ease;
      }

      /* Code blocks with copy button */
      pre {
        background: #2d2d2d;
        color: #e8e8e8;
        border-radius: 8px;
        padding: 16px;
        margin: 12px 0;
        overflow-x: auto;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        border-left: 4px solid #667eea;
        position: relative;
      }

      pre:hover .copy-code-btn {
        opacity: 1;
      }

      .copy-code-btn {
        position: absolute;
        top: 8px;
        right: 8px;
        background: rgba(102, 126, 234, 0.9);
        color: white;
        border: none;
        border-radius: 6px;
        padding: 6px 12px;
        font-size: 12px;
        font-weight: 500;
        cursor: pointer;
        opacity: 0;
        transition: all 0.2s ease;
        display: flex;
        align-items: center;
        gap: 4px;
        z-index: 10;
      }

      .copy-code-btn:hover {
        background: rgba(102, 126, 234, 1);
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
      }

      .copy-code-btn:active {
        transform: translateY(0);
      }

      .copy-code-btn.copied {
        background: #10B981;
        opacity: 1;
      }

      .copy-code-btn svg {
        width: 14px;
        height: 14px;
      }

      pre code {
        background: transparent;
        color: #e8e8e8;
        padding: 0;
        font-size: 13px;
        line-height: 1.6;
        font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
        display: block;
        white-space: pre;
      }
      
      /* Inline code */
      code {
        background: #f0f4ff;
        color: #667eea;
        padding: 2px 6px;
        border-radius: 4px;
        font-size: 13px;
        font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
        font-weight: 500;
      }
      
      pre code {
        background: transparent;
        color: #e8e8e8;
        padding: 0;
      }
      
      /* Markdown formatting */
      .message-content h1,
      .message-content h2,
      .message-content h3 {
        margin-top: 20px;
        margin-bottom: 12px;
        font-weight: 600;
        color: #2d3748;
        padding-bottom: 8px;
        border-bottom: 2px solid #e8ecf1;
      }
      
      .message-content h1 { font-size: 20px; }
      .message-content h2 { font-size: 18px; }
      .message-content h3 { font-size: 16px; }
      
      /* Horizontal rule for visual separation */
      .message-content hr {
        border: none;
        border-top: 2px solid #e8ecf1;
        margin: 20px 0;
      }
      
      /* Emoji-based step indicators */
      .message-content p:has(> strong:first-child) {
        background: #f7f9fc;
        padding: 12px;
        border-left: 4px solid #667eea;
        margin: 12px 0;
        border-radius: 4px;
      }
      
      .message-content p {
        margin: 8px 0;
      }
      
      .message-content ul,
      .message-content ol {
        margin: 12px 0;
        padding-left: 0;
        list-style: none;
      }
      
      .message-content li {
        margin: 8px 0;
        padding-left: 24px;
        position: relative;
      }
      
      .message-content ul li:before {
        content: '○';
        position: absolute;
        left: 8px;
        color: #667eea;
        font-weight: bold;
        font-size: 10px;
      }
      
      .message-content strong,
      .message-content b {
        font-weight: 700 !important;
        color: #1a202c !important;
      }

      .message-content em,
      .message-content i {
        font-style: italic !important;
      }

      .message-content code {
        background: #f1f5f9 !important;
        padding: 2px 6px !important;
        border-radius: 3px !important;
        font-family: 'Consolas', 'Monaco', 'Courier New', monospace !important;
        font-size: 0.9em !important;
        color: #e83e8c !important;
      }
      
      /* Scrollbar */
      .messages-container::-webkit-scrollbar {
        width: 8px;
      }
      
      .messages-container::-webkit-scrollbar-track {
        background: #f1f3f5;
      }
      
      .messages-container::-webkit-scrollbar-thumb {
        background: #cbd5e0;
        border-radius: 4px;
      }
      
      .messages-container::-webkit-scrollbar-thumb:hover {
        background: #a0aec0;
      }
      
      /* Loading indicator */
      /* Professional loading spinner */
      .typing-indicator {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 16px 20px;
        background: var(--message-assistant-bg);
        border-radius: 12px;
        box-shadow: 0 2px 10px var(--shadow-sm);
        border: 1px solid var(--border-light);
        width: fit-content;
        transition: all 0.3s ease;
      }

      .spinner-container {
        display: flex;
        align-items: center;
        gap: 10px;
      }

      .spinner {
        width: 20px;
        height: 20px;
        animation: spin 1s linear infinite;
      }

      @keyframes spin {
        from { transform: rotate(0deg); }
        to { transform: rotate(360deg); }
      }

      .typing-text {
        font-size: 14px;
        color: var(--text-secondary);
        font-weight: 500;
      }
      
      /* Streaming status badge */
      .streaming-status {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        padding: 4px 10px;
        background: var(--primary);
        color: white;
        border-radius: 6px;
        font-size: 11px;
        font-weight: 500;
        margin-bottom: 8px;
        animation: pulse 2s infinite;
      }
      
      @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.7; }
      }
      
      .streaming-status-icon {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        background: white;
        animation: blink 1s infinite;
      }
      
      @keyframes blink {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.3; }
      }
      
      /* Tool execution status - clean indicators */
      .tool-status {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 8px 14px;
        margin: 8px 0;
        border-radius: 8px;
        font-size: 13px;
        font-weight: 500;
        background: var(--bg-secondary);
        border: 1px solid var(--border-color);
        color: var(--text-secondary);
      }

      .tool-status.running {
        background: #FEF3C7;
        color: #92400E;
        border-color: #FDE68A;
      }

      .tool-status.running::before {
        content: '';
        width: 12px;
        height: 12px;
        border: 2px solid #F59E0B;
        border-top-color: transparent;
        border-radius: 50%;
        animation: spin 0.8s linear infinite;
      }

      .tool-status.complete {
        background: #D1FAE5;
        color: #065F46;
        border-color: #A7F3D0;
      }

      .tool-status.complete::before {
        content: '✓';
        color: #059669;
        font-weight: bold;
      }

      .tool-status.error {
        background: #FEE2E2;
        border-color: #FECACA;
        color: #991B1B;
      }

      .tool-status.error::before {
        content: '✕';
        color: #DC2626;
        font-weight: bold;
      }

      @keyframes spin {
        to { transform: rotate(360deg); }
      }
      
      /* Terminal-style streaming with event blocks */
      .message-content.streaming {
        position: relative;
      }

      .stream-event {
        display: flex;
        align-items: flex-start;
        gap: 10px;
        padding: 10px 12px;
        margin: 6px 0;
        background: var(--bg-secondary);
        border-left: 3px solid var(--primary);
        border-radius: 4px;
        font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
        font-size: 13px;
        animation: slideInEvent 0.3s ease-out;
        opacity: 0;
        animation-fill-mode: forwards;
      }

      @keyframes slideInEvent {
        from {
          opacity: 0;
          transform: translateX(-10px);
        }
        to {
          opacity: 1;
          transform: translateX(0);
        }
      }

      .stream-event-icon {
        flex-shrink: 0;
        width: 16px;
        height: 16px;
        margin-top: 2px;
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .stream-event-icon.running svg {
        animation: spin-tool 0.8s linear infinite;
        color: var(--primary);
      }

      .stream-event-icon.complete {
        color: #059669;
        font-weight: bold;
        font-size: 16px;
      }

      .stream-event-icon.error {
        color: #DC2626;
        font-weight: bold;
        font-size: 16px;
      }

      @keyframes spin-tool {
        from {
          transform: rotate(0deg);
        }
        to {
          transform: rotate(360deg);
        }
      }

      .stream-event-content {
        flex: 1;
        line-height: 1.5;
      }

      .stream-event-title {
        font-weight: 600;
        color: var(--text-primary);
        margin-bottom: 4px;
      }

      .stream-event-details {
        color: var(--text-secondary);
        font-size: 12px;
      }

      .stream-event.running {
        background: rgba(0, 102, 255, 0.05);
        border-left-color: var(--primary);
      }

      .stream-event.complete {
        background: rgba(5, 150, 105, 0.05);
        border-left-color: #059669;
      }

      .stream-event.error {
        background: rgba(220, 38, 38, 0.05);
        border-left-color: #DC2626;
      }

      .stream-final-output {
        margin-top: 12px;
        padding: 12px;
        background: var(--bg-tertiary);
        border-radius: 6px;
        animation: fadeIn 0.4s ease-in;
      }

      /* Tool Result Cards */
      .tool-result-card {
        margin: 8px 0;
        padding: 12px;
        background: var(--bg-secondary);
        border: 1px solid var(--border-color);
        border-radius: 6px;
        animation: fadeIn 0.3s ease-in;
      }

      .tool-result-header {
        display: flex;
        align-items: center;
        gap: 8px;
        font-weight: 600;
        color: var(--text-primary);
        margin-bottom: 8px;
        font-size: 13px;
      }

      .tool-result-icon {
        width: 16px;
        height: 16px;
        color: var(--primary);
      }

      .tool-result-content {
        padding: 8px;
        background: var(--bg-primary);
        border-radius: 4px;
        font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
        font-size: 12px;
        color: var(--text-secondary);
        max-height: 200px;
        overflow-y: auto;
        line-height: 1.5;
      }

      .tool-result-success {
        border-left: 3px solid #059669;
      }

      .tool-result-error {
        border-left: 3px solid #DC2626;
      }

      @keyframes fadeIn {
        from {
          opacity: 0;
        }
        to {
          opacity: 1;
        }
      }

      /* Style file input */
      input[type='file'] {
        display: none;
      }
      
      /* Style the file input wrapper */
      .shiny-input-container {
        background: var(--input-bg) !important;
        border-radius: 8px !important;
        transition: background 0.3s ease;
      }
      
      /* Style file input button and text */
      input[type='text'][readonly] {
        background: var(--input-bg) !important;
        color: var(--text-secondary) !important;
        border: 1px solid var(--border-light) !important;
        transition: all 0.3s ease;
      }
      
      .btn-file {
        background: var(--input-bg) !important;
        color: var(--text-primary) !important;
        border: 1px solid var(--border-light) !important;
        transition: all 0.3s ease;
      }
    "))
  ),
  
  # Enable shinyjs for resetting inputs
  shinyjs::useShinyjs(),
  
  div(class = "main-container",
    # Sidebar with chat history
    div(class = "sidebar",
      div(class = "sidebar-header",
        actionButton("newChatBtn", HTML("+ New Chat"), class = "new-chat-btn"),
        div(style = "margin-top: 12px; display: flex; gap: 6px;",
          actionButton("openFolderBtn", HTML('<svg width="20" height="20" fill="currentColor" viewBox="0 0 24 24"><path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>'), class = "workspace-btn", title = "Open Folder"),
          actionButton("openFileBtn", HTML('<svg width="20" height="20" fill="currentColor" viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>'), class = "workspace-btn", title = "Open File")
        ),
        uiOutput("workspaceInfo")
      ),
      div(class = "chat-history",
        uiOutput("chatHistory")
      )
    ),
    # Main chat area
    div(class = "chat-container",
      div(class = "chat-area",
      div(class = "app-header",
        tags$button(
          class = "sidebar-toggle",
          id = "sidebarToggle",
          onclick = "toggleSidebarDirect()",
          HTML('<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path></svg>')
        ),
        div(class = "header-content",
          div(
            h1("Rflow AI Assistant"),
            p(class = "header-subtitle", "Your intelligent R coding companion")
          )
        ),
        tags$button(
          class = "sidebar-toggle",
          id = "themeToggle",
          onclick = "toggleThemeDirect()",
          HTML('<svg id="themeIcon" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"></path></svg>')
        )
      ),
      div(class = "messages-container", id = "messagesContainer",
        uiOutput("messages")
      ),
      div(class = "quick-actions-bar",
        tags$button(
          class = "quick-action-btn",
          onclick = "var msg = 'Load my data file into R. If it\\'s a CSV use read.csv(), if Excel use readxl::read_excel(). Store it in a variable called \\'my_data\\' and show me a summary with str(), head(), and basic statistics.'; $('#messageInput').val(msg).trigger('change'); document.getElementById('messageInput').focus();",
          HTML('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
            <polyline points="17 8 12 3 7 8"></polyline>
            <line x1="12" y1="3" x2="12" y2="15"></line>
          </svg>
          <span>Load Data</span>')
        ),
        tags$button(
          class = "quick-action-btn",
          onclick = "var msg = 'Analyze the loaded dataset. Show summary statistics, check for missing values, identify data types, and create distribution plots for key variables.'; $('#messageInput').val(msg).trigger('change'); document.getElementById('messageInput').focus();",
          HTML('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="20" x2="12" y2="10"></line>
            <line x1="18" y1="20" x2="18" y2="4"></line>
            <line x1="6" y1="20" x2="6" y2="16"></line>
          </svg>
          <span>Analyze Data</span>')
        ),
        tags$button(
          class = "quick-action-btn",
          onclick = "var msg = 'Create a professional ggplot2 visualization with proper titles, labels, and theme. Make it publication-ready with clear legends and appropriate color schemes'; $('#messageInput').val(msg).trigger('change'); document.getElementById('messageInput').focus();",
          HTML('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline>
          </svg>
          <span>Create Plot</span>')
        ),
        tags$button(
          class = "quick-action-btn",
          onclick = "var msg = 'Build a statistical model (linear regression, logistic regression, or appropriate model) for my data. Include model diagnostics, performance metrics, and interpretation of coefficients'; $('#messageInput').val(msg).trigger('change'); document.getElementById('messageInput').focus();",
          HTML('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="12" y1="8" x2="12" y2="16"></line>
            <line x1="8" y1="12" x2="16" y2="12"></line>
          </svg>
          <span>Build Model</span>')
        ),
        tags$button(
          class = "quick-action-btn",
          onclick = "var msg = 'Review my R code for errors, bugs, and potential issues. Check for common mistakes like incorrect indexing, missing packages, data type mismatches, and provide fixes with explanations'; $('#messageInput').val(msg).trigger('change'); document.getElementById('messageInput').focus();",
          HTML('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z"></path>
            <path d="M12 8v4"></path>
            <path d="M12 16h.01"></path>
          </svg>
          <span>Debug Code</span>')
        ),
        tags$button(
          class = "quick-action-btn",
          onclick = "var msg = 'Optimize my R code for better performance. Suggest vectorization, use of data.table/dplyr instead of loops, parallel processing where applicable, and memory efficiency improvements'; $('#messageInput').val(msg).trigger('change'); document.getElementById('messageInput').focus();",
          HTML('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
          </svg>
          <span>Optimize</span>')
        )
      ),
      div(class = "input-area",
        uiOutput("fileAttachments"),
        div(class = "input-wrapper",
          div(class = "message-input-container",
            textAreaInput(
              "messageInput",
              NULL,
              placeholder = "Type your message here...",
              width = "100%",
              resize = "none"
            ),
            tags$script(HTML("
              // Enter to send
              $(document).on('keydown', '#messageInput', function(e) {
                if(e.keyCode == 13 && !e.shiftKey) {
                  e.preventDefault();
                  $('#sendBtn').click();
                  // Clear input immediately (client-side for instant feedback)
                  setTimeout(function() {
                    $('#messageInput').val('');
                  }, 100);
                }
              });

              // Clear input when send button is clicked
              $(document).on('click', '#sendBtn', function() {
                // Clear input immediately (client-side for instant feedback)
                setTimeout(function() {
                  $('#messageInput').val('');
                }, 100);
              });
              
              // Paste support for images
              $(document).on('paste', '#messageInput', function(e) {
                var clipboardData = e.originalEvent.clipboardData;
                if (!clipboardData) return;
                
                var items = clipboardData.items;
                if (!items) return;
                
                for (var i = 0; i < items.length; i++) {
                  var item = items[i];
                  
                  // Handle pasted images
                  if (item.type.indexOf('image') !== -1) {
                    e.preventDefault();
                    
                    var blob = item.getAsFile();
                    var timestamp = new Date().getTime();
                    
                    // Convert blob to base64
                    var reader = new FileReader();
                    reader.onload = function(event) {
                      var base64data = event.target.result;
                      
                      // Send to Shiny
                      Shiny.setInputValue('pastedImage', {
                        data: base64data,
                        timestamp: timestamp,
                        type: blob.type
                      }, {priority: 'event'});
                      
                      console.log('📎 Image pasted and sent to server');
                    };
                    reader.readAsDataURL(blob);
                    
                    break;
                  }
                }
              });
            "))
          ),
          tags$label(class = "file-upload-btn", `for` = "fileUpload", title = "Attach file",
            HTML('<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path></svg>'),
            fileInput("fileUpload", NULL, multiple = TRUE, accept = c(
              # Spreadsheets
              ".xlsx", ".xls", ".csv", ".tsv", ".ods",
              # Images
              ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg", ".webp", ".tiff",
              # Documents
              ".pdf", ".txt", ".doc", ".docx", ".odt",
              # Code
              ".R", ".Rmd", ".py", ".sql", ".json", ".xml", ".html", ".css", ".js",
              # Data
              ".rds", ".rda", ".RData", ".feather", ".parquet",
              # Archives
              ".zip", ".tar", ".gz"
            ))
          ),
          actionButton("sendBtn", HTML('
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 4px;">
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
            Send
          '), class = "send-btn")
        )
      )
      )
    )
  ),
  
  tags$script(HTML("
    // Auto-scroll to bottom when new messages arrive
    function scrollToBottom() {
      var container = document.getElementById('messagesContainer');
      if (container) {
        container.scrollTop = container.scrollHeight;
      }
    }
    
    // Observe changes in messages container
    var observer = new MutationObserver(scrollToBottom);
    var config = { childList: true, subtree: true };
    
    setTimeout(function() {
      var container = document.getElementById('messagesContainer');
      if (container) {
        observer.observe(container, config);
      }
    }, 100);

    // Client-side toggle functions (work even during streaming)
    var sidebarCollapsed = false;
    var darkModeEnabled = false;

    window.toggleSidebarDirect = function() {
      var sidebar = document.querySelector('.sidebar');
      if (sidebar) {
        sidebarCollapsed = !sidebarCollapsed;
        if (sidebarCollapsed) {
          sidebar.classList.add('collapsed');
        } else {
          sidebar.classList.remove('collapsed');
        }
      }
    };

    window.toggleThemeDirect = function() {
      var html = document.documentElement;
      var icon = document.getElementById('themeIcon');

      darkModeEnabled = !darkModeEnabled;

      if (darkModeEnabled) {
        html.classList.add('dark-mode');
        // Change to sun icon for light mode
        if (icon) {
          icon.innerHTML = '<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z\"></path>';
        }
      } else {
        html.classList.remove('dark-mode');
        // Change to moon icon for dark mode
        if (icon) {
          icon.innerHTML = '<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z\"></path>';
        }
      }
    };

    // Add copy buttons to all code blocks
    function addCopyButtonsToCodeBlocks() {
      var codeBlocks = document.querySelectorAll('pre code');
      codeBlocks.forEach(function(codeBlock) {
        var pre = codeBlock.parentElement;

        // Skip if button already exists
        if (pre.querySelector('.copy-code-btn')) return;

        // Create copy button
        var copyBtn = document.createElement('button');
        copyBtn.className = 'copy-code-btn';
        var copyIcon = '<svg fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z\"></path></svg>';
        copyBtn.innerHTML = copyIcon + '<span>Copy</span>';

        // Copy functionality
        copyBtn.addEventListener('click', function(e) {
          e.preventDefault();
          e.stopPropagation();

          var code = codeBlock.textContent;

          var checkIcon = '<svg fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M5 13l4 4L19 7\"></path></svg>';
          var copiedHtml = checkIcon + '<span>Copied!</span>';
          var defaultHtml = copyIcon + '<span>Copy</span>';

          // Use clipboard API
          if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(code).then(function() {
              // Show success
              copyBtn.innerHTML = copiedHtml;
              copyBtn.classList.add('copied');

              // Reset after 2 seconds
              setTimeout(function() {
                copyBtn.innerHTML = defaultHtml;
                copyBtn.classList.remove('copied');
              }, 2000);
            }).catch(function(err) {
              console.error('Failed to copy:', err);
            });
          } else {
            // Fallback for older browsers
            var textArea = document.createElement('textarea');
            textArea.value = code;
            textArea.style.position = 'fixed';
            textArea.style.left = '-999999px';
            document.body.appendChild(textArea);
            textArea.select();
            try {
              document.execCommand('copy');
              copyBtn.innerHTML = copiedHtml;
              copyBtn.classList.add('copied');
              setTimeout(function() {
                copyBtn.innerHTML = defaultHtml;
                copyBtn.classList.remove('copied');
              }, 2000);
            } catch (err) {
              console.error('Failed to copy:', err);
            }
            document.body.removeChild(textArea);
          }
        });

        pre.appendChild(copyBtn);
      });
    }

    // Format relative timestamp (e.g., 2 minutes ago, just now)
    function formatTimestamp(date) {
      var now = new Date();
      var diffMs = now - date;
      var diffSecs = Math.floor(diffMs / 1000);
      var diffMins = Math.floor(diffSecs / 60);
      var diffHours = Math.floor(diffMins / 60);
      var diffDays = Math.floor(diffHours / 24);

      if (diffSecs < 10) return 'just now';
      if (diffSecs < 60) return diffSecs + ' seconds ago';
      if (diffMins === 1) return '1 minute ago';
      if (diffMins < 60) return diffMins + ' minutes ago';
      if (diffHours === 1) return '1 hour ago';
      if (diffHours < 24) return diffHours + ' hours ago';
      if (diffDays === 1) return '1 day ago';
      if (diffDays < 7) return diffDays + ' days ago';

      // For older messages, show date
      var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return months[date.getMonth()] + ' ' + date.getDate();
    }

    // Add timestamp to message
    function addTimestampToMessage(messageElement) {
      // Check if timestamp already exists
      if (messageElement.querySelector('.message-timestamp')) return;

      var timestamp = new Date();
      var timestampEl = document.createElement('div');
      timestampEl.className = 'message-timestamp';
      timestampEl.textContent = formatTimestamp(timestamp);
      timestampEl.setAttribute('data-timestamp', timestamp.toISOString());

      // Add to message content
      var content = messageElement.querySelector('.message-content');
      if (content) {
        content.parentElement.appendChild(timestampEl);
      }
    }

    // Update timestamps every minute
    setInterval(function() {
      var timestamps = document.querySelectorAll('.message-timestamp');
      timestamps.forEach(function(el) {
        var isoTime = el.getAttribute('data-timestamp');
        if (isoTime) {
          var date = new Date(isoTime);
          el.textContent = formatTimestamp(date);
        }
      });
    }, 60000); // Update every minute

    // Observe DOM changes to add copy buttons and timestamps
    var codeBlockObserver = new MutationObserver(function(mutations) {
      addCopyButtonsToCodeBlocks();

      // Add timestamps to new messages
      mutations.forEach(function(mutation) {
        mutation.addedNodes.forEach(function(node) {
          if (node.nodeType === 1) { // Element node
            if (node.classList && node.classList.contains('message')) {
              addTimestampToMessage(node);
            }
            // Check children for messages
            var messages = node.querySelectorAll && node.querySelectorAll('.message');
            if (messages) {
              messages.forEach(function(msg) {
                addTimestampToMessage(msg);
              });
            }
          }
        });
      });
    });

    // Start observing
    setTimeout(function() {
      var container = document.getElementById('messages');
      if (container) {
        codeBlockObserver.observe(container, { childList: true, subtree: true });
      }

      // Add buttons and timestamps to existing elements
      addCopyButtonsToCodeBlocks();
      document.querySelectorAll('.message').forEach(function(msg) {
        addTimestampToMessage(msg);
      });
    }, 500);

    // Legacy Shiny message handlers (kept for backwards compatibility)
    Shiny.addCustomMessageHandler('toggleSidebarClass', function(collapsed) {
      sidebarCollapsed = collapsed;
      var sidebar = document.querySelector('.sidebar');
      if (sidebar) {
        if (collapsed) {
          sidebar.classList.add('collapsed');
        } else {
          sidebar.classList.remove('collapsed');
        }
      }
    });

    Shiny.addCustomMessageHandler('toggleThemeClass', function(isDark) {
      darkModeEnabled = isDark;
      var html = document.documentElement;
      var icon = document.getElementById('themeIcon');

      if (isDark) {
        html.classList.add('dark-mode');
        // Change to sun icon for light mode
        icon.innerHTML = '<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z\"></path>';
      } else {
        html.classList.remove('dark-mode');
        // Change to moon icon for dark mode
        icon.innerHTML = '<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z\"></path>';
      }
    });
    
    // Terminal-style event streaming handler
    var currentEvents = [];
    var eventIdCounter = 0;

    Shiny.addCustomMessageHandler('updateLastMessage', function(message) {
      var container = document.getElementById('messages');
      if (!container) return;

      // Get all assistant messages
      var messages = container.querySelectorAll('.message-assistant');

      if (messages.length > 0) {
        var lastMsg = messages[messages.length - 1];
        var contentDiv = lastMsg.querySelector('.message-content');
        var avatar = lastMsg.querySelector('.message-avatar');

        if (contentDiv) {
          if (message.streaming) {
            // Terminal-style: render as progressive events
            contentDiv.classList.add('streaming');
            if (avatar) avatar.classList.add('thinking');
            renderTerminalStream(contentDiv, message.content);
          } else {
            // Streaming complete: finalize
            contentDiv.classList.remove('streaming');
            if (avatar) avatar.classList.remove('thinking');
            finalizeTerminalStream(contentDiv, message.content);
          }
        }
      } else {
        // Create new message with terminal streaming
        var msgDiv = document.createElement('div');
        msgDiv.className = 'message message-assistant';
        var avatarSvg = \"<svg fill='currentColor' viewBox='0 0 24 24'>\" +
          \"<path d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z\" +
          \"m0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3z\" +
          \"m0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z'/></svg>\";
        msgDiv.innerHTML = \"<div class='message-avatar thinking'>\" + avatarSvg + \"</div>\" +
          \"<div class='message-content streaming'></div>\";
        container.appendChild(msgDiv);

        var contentDiv = msgDiv.querySelector('.message-content');
        renderTerminalStream(contentDiv, message.content);
      }

      // Smooth scroll
      var isNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 150;
      if (isNearBottom || message.streaming) {
        requestAnimationFrame(scrollToBottom);
      }
    });

    // Render terminal-style streaming events (multiple progressive events)
    function renderTerminalStream(contentDiv, text) {
      // Clean text first
      var cleanText = text
        .replace(/\\[EXPLORING\\]|\\[SUCCESS\\]|\\[CREATING\\]|\\[RUNNING\\]|\\[COMPLETE\\]|\\[ERROR\\]|\\[ANALYZING\\]|\\[WRITING\\]|\\[READING\\]|\\[FIXING\\]|\\[TESTING\\]|\\[BUILDING\\]|\\[OPTIMIZING\\]/gi, '')
        .replace(/<br>/g, ' ')
        .replace(/\\s+/g, ' ')
        .trim();

      if (!cleanText || cleanText.length < 5) return;

      // Split into sentences for progressive events
      var sentences = cleanText.match(/[^.!?]+[.!?]+/g) || [];
      var lastPartial = cleanText.substring(cleanText.lastIndexOf('.') + 1).trim();

      // Get existing events
      var existingEvents = contentDiv.querySelectorAll('.stream-event');
      var existingCount = existingEvents.length;

      // Add completed events for finished sentences
      if (sentences.length > existingCount) {
        for (var i = existingCount; i < sentences.length; i++) {
          var sentence = sentences[i].trim();
          if (sentence && sentence.length > 10) {
            var eventDiv = createStreamEvent(sentence, 'complete');
            contentDiv.appendChild(eventDiv);
          }
        }
      }

      // Update or create running event for partial sentence
      if (lastPartial && lastPartial.length > 10) {
        var runningEvent = contentDiv.querySelector('.stream-event.running');
        if (runningEvent) {
          // Update existing running event
          var titleDiv = runningEvent.querySelector('.stream-event-title');
          if (titleDiv) {
            titleDiv.innerHTML = lastPartial;
          }
        } else {
          // Create new running event
          var eventDiv = createStreamEvent(lastPartial, 'running');
          contentDiv.appendChild(eventDiv);
        }
      }
    }

    // Create a stream event block
    function createStreamEvent(text, status) {
      var eventDiv = document.createElement('div');
      eventDiv.className = 'stream-event ' + status;

      // Icon (settings gear for running, checkmark for complete, X for error)
      var iconDiv = document.createElement('div');
      iconDiv.className = 'stream-event-icon ' + status;

      if (status === 'running') {
        // Settings/gear icon SVG (spinning)
        iconDiv.innerHTML = '<svg fill=\"currentColor\" viewBox=\"0 0 24 24\" width=\"16\" height=\"16\">' +
          '<path d=\"M12 15.5A3.5 3.5 0 0 1 8.5 12 3.5 3.5 0 0 1 12 8.5a3.5 3.5 0 0 1 3.5 3.5 3.5 3.5 0 0 1-3.5 3.5m7.43-2.53c.04-.32.07-.64.07-.97 0-.33-.03-.66-.07-1l2.11-1.63c.19-.15.24-.42.12-.64l-2-3.46c-.12-.22-.39-.31-.61-.22l-2.49 1c-.52-.39-1.06-.73-1.69-.98l-.37-2.65c-.04-.24-.25-.42-.5-.42h-4c-.25 0-.46.18-.5.42l-.37 2.65c-.63.25-1.17.59-1.69.98l-2.49-1c-.22-.09-.49 0-.61.22l-2 3.46c-.13.22-.07.49.12.64L4.57 11c-.04.34-.07.67-.07 1 0 .33.03.65.07.97l-2.11 1.66c-.19.15-.25.42-.12.64l2 3.46c.12.22.39.3.61.22l2.49-1.01c.52.4 1.06.74 1.69.99l.37 2.65c.04.24.25.42.5.42h4c.25 0 .46-.18.5-.42l.37-2.65c.63-.26 1.17-.59 1.69-.99l2.49 1.01c.22.08.49 0 .61-.22l2-3.46c.12-.22.07-.49-.12-.64l-2.11-1.66z\"/>' +
          '</svg>';
      } else if (status === 'complete') {
        iconDiv.textContent = '✓';
      } else if (status === 'error') {
        iconDiv.textContent = '✕';
      }

      // Content
      var contentDiv = document.createElement('div');
      contentDiv.className = 'stream-event-content';

      var titleDiv = document.createElement('div');
      titleDiv.className = 'stream-event-title';
      titleDiv.innerHTML = text;

      contentDiv.appendChild(titleDiv);
      eventDiv.appendChild(iconDiv);
      eventDiv.appendChild(contentDiv);

      return eventDiv;
    }

    // Finalize terminal stream
    function finalizeTerminalStream(contentDiv, fullText) {
      // Remove any streaming events
      var streamingEvents = contentDiv.querySelectorAll('.stream-event');
      streamingEvents.forEach(function(event) {
        event.remove();
      });

      // Clean up the final text
      var cleanFinalText = fullText
        .replace(/\\[EXPLORING\\]|\\[SUCCESS\\]|\\[CREATING\\]|\\[RUNNING\\]|\\[COMPLETE\\]|\\[ERROR\\]|\\[ANALYZING\\]|\\[WRITING\\]|\\[READING\\]|\\[FIXING\\]|\\[TESTING\\]|\\[BUILDING\\]|\\[OPTIMIZING\\]/gi, '')
        .replace(/<br><br><br>/g, '<br><br>')
        .replace(/^\\s*<br>\\s*|\\s*<br>\\s*$/g, '')
        .trim();

      // Show the complete rendered markdown response
      if (cleanFinalText.length > 0) {
        contentDiv.innerHTML = cleanFinalText;
      }
    }
    
    // Show streaming status badge
    Shiny.addCustomMessageHandler('showStreamingStatus', function(data) {
      var container = document.getElementById('messages');
      if (!container) return;
      
      var messages = container.querySelectorAll('.message-assistant');
      if (messages.length > 0) {
        var lastMsg = messages[messages.length - 1];
        var contentDiv = lastMsg.querySelector('.message-content');
        if (contentDiv) {
          var badge = \"<div class='streaming-status'>\" +
            \"<div class='streaming-status-icon'></div>\" + data.text + \"</div>\";
          contentDiv.innerHTML = badge + contentDiv.innerHTML;
        }
      }
    });
    
    // Comprehensive activity status system with 50+ status messages
    var currentToolStatus = null;

    // Master list of all possible status messages (50+ activities)
    var activityMessages = {
      // Code Execution (10)
      'run_r_code': 'Running R code',
      'execute_script': 'Executing script',
      'eval_expression': 'Evaluating expression',
      'compile_code': 'Compiling code',
      'test_code': 'Testing code',
      'debug_code': 'Debugging code',
      'profile_code': 'Profiling performance',
      'optimize_code': 'Optimizing code',
      'validate_syntax': 'Validating syntax',
      'format_code': 'Formatting code',

      // File Operations (10)
      'write_text_file': 'Writing file',
      'read_text_file': 'Reading file',
      'analyze_file': 'Analyzing file',
      'create_directory': 'Creating directory',
      'delete_path': 'Deleting file',
      'copy_path': 'Copying file',
      'move_path': 'Moving file',
      'list_directory': 'Listing directory',
      'search_files': 'Searching files',
      'scan_directory': 'Scanning directory',

      // Data Analysis (10)
      'load_data': 'Loading dataset',
      'clean_data': 'Cleaning data',
      'transform_data': 'Transforming data',
      'analyze_data': 'Analyzing data',
      'summarize_stats': 'Computing statistics',
      'check_missing': 'Checking missing values',
      'detect_outliers': 'Detecting outliers',
      'validate_data': 'Validating data',
      'merge_data': 'Merging datasets',
      'reshape_data': 'Reshaping data',

      // Visualization (8)
      'create_plot': 'Creating visualization',
      'generate_chart': 'Generating chart',
      'build_dashboard': 'Building dashboard',
      'render_plot': 'Rendering plot',
      'export_figure': 'Exporting figure',
      'style_plot': 'Styling visualization',
      'add_annotations': 'Adding annotations',
      'save_plot': 'Saving plot',

      // Modeling (8)
      'build_model': 'Building model',
      'train_model': 'Training model',
      'test_model': 'Testing model',
      'validate_model': 'Validating model',
      'tune_parameters': 'Tuning parameters',
      'evaluate_metrics': 'Evaluating metrics',
      'predict_outcomes': 'Making predictions',
      'compare_models': 'Comparing models',

      // System Operations (5)
      'run_command': 'Running command',
      'install_package': 'Installing package',
      'load_library': 'Loading library',
      'check_environment': 'Checking environment',
      'configure_settings': 'Configuring settings',

      // Problem Solving (5)
      'fix_error': 'Fixing error',
      'troubleshoot': 'Troubleshooting issue',
      'handle_exception': 'Handling exception',
      'recover_data': 'Recovering data',
      'retry_operation': 'Retrying operation',

      // Documentation (4)
      'generate_docs': 'Generating documentation',
      'create_readme': 'Creating README',
      'write_comments': 'Writing comments',
      'document_functions': 'Documenting functions'
    };

    Shiny.addCustomMessageHandler('updateToolStatus', function(data) {
      console.log('🔧 Status:', data.tool, '-', data.status);

      var container = document.getElementById('messages');
      if (!container) return;

      var activityName = activityMessages[data.tool] || data.tool.replace(/_/g, ' ');
      var statusClass = data.status || 'running';

      // Remove any existing tool status
      if (currentToolStatus) {
        currentToolStatus.remove();
        currentToolStatus = null;
      }

      if (statusClass === 'running') {
        // Add new status indicator
        var statusDiv = document.createElement('div');
        statusDiv.className = 'tool-status running';
        statusDiv.textContent = activityName + '...';

        // Find last assistant message and append
        var messages = container.querySelectorAll('.message-assistant');
        if (messages.length > 0) {
          var lastMsg = messages[messages.length - 1];
          var contentDiv = lastMsg.querySelector('.message-content');
          if (contentDiv) {
            contentDiv.appendChild(statusDiv);
            currentToolStatus = statusDiv;
            scrollToBottom();
          }
        }
      } else if (statusClass === 'complete') {
        // Show brief completion status
        if (currentToolStatus) {
          currentToolStatus.className = 'tool-status complete';
          currentToolStatus.textContent = activityName + ' complete';
          setTimeout(function() {
            if (currentToolStatus) {
              currentToolStatus.remove();
              currentToolStatus = null;
            }
          }, 1500);
        }
      } else if (statusClass === 'error') {
        // Show error status
        if (currentToolStatus) {
          currentToolStatus.className = 'tool-status error';
          currentToolStatus.textContent = 'Error: ' + activityName;
        }
      }
    });
  "))
)

cat("UI created\n")

server <- function(input, output, session) {
  cat("Server function started\n")
  
  # Simplified markdown rendering with HTML/CSS
  # SECURITY: Properly escapes HTML to prevent XSS attacks
  render_markdown <- function(text) {
    if (is.null(text) || nchar(text) == 0) return("")

    html <- text

    # SECURITY FIX: Extract code blocks FIRST before HTML escaping
    code_blocks <- list()
    inline_codes <- list()

    # Extract multi-line code blocks (```...```)
    code_pattern <- "```[rR]?\\n?([^`]+)```"
    matches <- gregexpr(code_pattern, html, perl = TRUE)

    if (matches[[1]][1] != -1) {
      matched_texts <- regmatches(html, matches)[[1]]
      for (i in seq_along(matched_texts)) {
        code_content <- sub("```[rR]?\\n?", "", matched_texts[i])
        code_content <- sub("```$", "", code_content)
        code_blocks[[i]] <- code_content
      }
      for (i in seq_along(matched_texts)) {
        html <- sub(code_pattern, paste0("__CODEBLOCK", i, "__"), html, perl = TRUE)
      }
    }

    # Extract inline code (`...`)
    inline_pattern <- "`([^`]+)`"
    inline_matches <- gregexpr(inline_pattern, html, perl = TRUE)

    if (inline_matches[[1]][1] != -1) {
      inline_texts <- regmatches(html, inline_matches)[[1]]
      for (i in seq_along(inline_texts)) {
        inline_content <- sub("^`", "", inline_texts[i])
        inline_content <- sub("`$", "", inline_content)
        inline_codes[[i]] <- inline_content
      }
      for (i in seq_along(inline_texts)) {
        html <- sub(inline_pattern, paste0("__INLINECODE", i, "__"), html, perl = FALSE)
      }
    }

    # SECURITY FIX: NOW escape all HTML entities to prevent XSS
    # This prevents <script>, <img onerror>, and other malicious HTML
    html <- gsub("&", "&amp;", html, fixed = TRUE)
    html <- gsub("<", "&lt;", html, fixed = TRUE)
    html <- gsub(">", "&gt;", html, fixed = TRUE)
    html <- gsub("\"", "&quot;", html, fixed = TRUE)
    html <- gsub("'", "&#39;", html, fixed = TRUE)

    # NOW safe to convert markdown to HTML (on escaped text)
    # Bold: **text** (need to unescape the <b> tags we create)
    html <- gsub("\\*\\*(.+?)\\*\\*", "<b>\\1</b>", html)

    # Headers
    html <- gsub("^### (.+)$", "<h3>\\1</h3>", html, perl = TRUE)
    html <- gsub("^## (.+)$", "<h2>\\1</h2>", html, perl = TRUE)
    html <- gsub("^# (.+)$", "<h1>\\1</h1>", html, perl = TRUE)

    # Lists
    html <- gsub("^- (.+)$", "<li>\\1</li>", html, perl = TRUE)
    html <- gsub("^\\* (.+)$", "<li>\\1</li>", html, perl = TRUE)
    html <- gsub("^[0-9]+\\. (.+)$", "<li>\\1</li>", html, perl = TRUE)

    # Unescape our own HTML tags (but not user content)
    html <- gsub("&lt;b&gt;", "<b>", html, fixed = TRUE)
    html <- gsub("&lt;/b&gt;", "</b>", html, fixed = TRUE)
    html <- gsub("&lt;h1&gt;", "<h1>", html, fixed = TRUE)
    html <- gsub("&lt;/h1&gt;", "</h1>", html, fixed = TRUE)
    html <- gsub("&lt;h2&gt;", "<h2>", html, fixed = TRUE)
    html <- gsub("&lt;/h2&gt;", "</h2>", html, fixed = TRUE)
    html <- gsub("&lt;h3&gt;", "<h3>", html, fixed = TRUE)
    html <- gsub("&lt;/h3&gt;", "</h3>", html, fixed = TRUE)
    html <- gsub("&lt;li&gt;", "<li>", html, fixed = TRUE)
    html <- gsub("&lt;/li&gt;", "</li>", html, fixed = TRUE)
    html <- gsub("&lt;ul&gt;", "<ul>", html, fixed = TRUE)
    html <- gsub("&lt;/ul&gt;", "</ul>", html, fixed = TRUE)

    # Line breaks
    html <- gsub("\n", "<br>", html)

    # Restore inline code (already safe - will be escaped)
    for (i in seq_along(inline_codes)) {
      code_content <- inline_codes[[i]]
      # Already escaped above, just wrap in <code>
      code_html <- paste0("<code>", code_content, "</code>")
      html <- gsub(paste0("__INLINECODE", i, "__"), code_html, html, fixed = TRUE)
    }

    # Restore code blocks (already safe - will be escaped)
    for (i in seq_along(code_blocks)) {
      code_content <- code_blocks[[i]]
      # Already escaped above, just wrap in <pre><code>
      code_html <- paste0("<pre><code class='language-r'>", code_content, "</code></pre>")
      html <- gsub(paste0("__CODEBLOCK", i, "__"), code_html, html, fixed = TRUE)
    }

    # Wrap consecutive list items
    html <- gsub("(<li>.+?</li>)<br>(<li>)", "\\1\\2", html)
    html <- gsub("(<li>.+?</li>)+", "<ul>\\0</ul>", html)

    return(html)
  }
  
  # Store messages for current chat
  messages <- reactiveVal(list())
  
  # Store all chat sessions
  chat_sessions <- reactiveVal(list())
  current_chat_id <- reactiveVal(1)
  
  # Initialize first chat session
  observe({
    if (length(chat_sessions()) == 0) {
      chat_sessions(list(
        list(
          id = 1,
          title = "New Chat",
          messages = list(),
          timestamp = Sys.time()
        )
      ))
    }
  })
  
  # Sidebar toggle state
  sidebar_collapsed <- reactiveVal(FALSE)
  
  # Toggle sidebar
  observeEvent(input$toggleSidebar, {
    new_state <- !sidebar_collapsed()
    sidebar_collapsed(new_state)
    session$sendCustomMessage('toggleSidebarClass', new_state)
    cat("Sidebar toggled:", if(new_state) "collapsed" else "expanded", "\n")
  })
  
  # Theme toggle state
  dark_mode <- reactiveVal(FALSE)
  
  # Toggle theme
  observeEvent(input$toggleTheme, {
    new_state <- !dark_mode()
    dark_mode(new_state)
    session$sendCustomMessage('toggleThemeClass', new_state)
    cat("Theme toggled:", if(new_state) "dark" else "light", "\n")
  })
  
  # Store uploaded files
  uploaded_files <- reactiveVal(list())
  
  # Workspace state
  workspace_folder <- reactiveVal(NULL)
  workspace_files <- reactiveVal(list())
  
  # Open Folder button handler
  observeEvent(input$openFolderBtn, {
    tryCatch({
      folder_path <- rstudioapi::selectDirectory(
        caption = "Select Working Folder",
        label = "Open"
      )
      
      if (!is.null(folder_path) && dir.exists(folder_path)) {
        folder_path <- normalizePath(folder_path, winslash = "/")
        workspace_folder(folder_path)
        
        # Scan folder recursively (includes all subfolders)
        all_files <- list.files(folder_path, recursive = TRUE, full.names = TRUE)
        all_dirs <- list.dirs(folder_path, recursive = TRUE, full.names = TRUE)
        workspace_files(all_files)
        
        # Count by type
        r_files <- sum(grepl("\\.(R|Rmd|rmd)$", all_files, ignore.case = TRUE))
        data_files <- sum(grepl("\\.(csv|xlsx|xls|json|rds|rda|parquet)$", all_files, ignore.case = TRUE))
        
        cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        cat("📁 Opened folder:", folder_path, "\n")
        cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        cat("   📂 Subfolders:", length(all_dirs) - 1, "\n")
        cat("   📄 Total files:", length(all_files), "\n")
        cat("   📊 R files:", r_files, "\n")
        cat("   📈 Data files:", data_files, "\n")
        cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      }
    }, error = function(e) {
      cat("Error opening folder:", conditionMessage(e), "\n")
    })
  })
  
  # Open File button handler
  observeEvent(input$openFileBtn, {
    tryCatch({
      file_path <- rstudioapi::selectFile(
        caption = "Select File to Open",
        filter = "All Files (*.*)"
      )
      
      if (!is.null(file_path) && file.exists(file_path)) {
        file_path <- normalizePath(file_path, winslash = "/")
        
        # Add to tracked files
        current_files <- workspace_files()
        if (!file_path %in% current_files) {
          workspace_files(c(current_files, file_path))
        }
        
        # Open in RStudio editor
        rstudioapi::navigateToFile(file_path)
        
        cat("📄 Opened file:", basename(file_path), "\n")
      }
    }, error = function(e) {
      cat("Error opening file:", conditionMessage(e), "\n")
    })
  })
  
  # Render workspace info in sidebar
  output$workspaceInfo <- renderUI({
    folder <- workspace_folder()
    files <- workspace_files()
    
    if (is.null(folder) && length(files) == 0) {
      return(NULL)
    }
    
    div(class = "workspace-info",
      if (!is.null(folder)) {
        tagList(
          div(class = "folder-name", title = folder, style = "display: flex; align-items: center; gap: 6px;",
            HTML('<svg width="14" height="14" fill="currentColor" viewBox="0 0 24 24"><path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>'),
            span(basename(folder))
          ),
          div(class = "file-count",
            paste0(length(files), " files"))
        )
      } else if (length(files) > 0) {
        div(class = "file-count",
          paste0(length(files), " files open"))
      }
    )
  })
  
  # Save messages to current chat session whenever they change
  observe({
    current_msgs <- messages()
    current_id <- current_chat_id()
    sessions <- chat_sessions()
    
    if (length(sessions) > 0 && current_id <= length(sessions)) {
      # Update the current session's messages
      sessions[[current_id]]$messages <- current_msgs
      
      # Update title based on first user message
      if (length(current_msgs) > 0 && sessions[[current_id]]$title == "New Chat") {
        first_user_msg <- Find(function(m) m$role == "user", current_msgs)
        if (!is.null(first_user_msg)) {
          # Use first 30 characters of first message as title
          title <- substr(first_user_msg$content, 1, 30)
          if (nchar(first_user_msg$content) > 30) title <- paste0(title, "...")
          sessions[[current_id]]$title <- title
        }
      }
      
      chat_sessions(sessions)
    }
  })
  
  # Render messages
  output$messages <- renderUI({
    msg_list <- messages()
    if (length(msg_list) == 0) {
      return(div(class = "message message-assistant",
        div(class = "message-avatar",
          HTML('<svg fill="currentColor" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/></svg>')
        ),
        div(class = "message-content welcome-message",
          HTML("
            <style>
              .status-badge {
                display: inline-flex;
                align-items: center;
                gap: 8px;
                padding: 8px 12px;
                background: #FEF3C7;
                border: 1px solid #FCD34D;
                border-radius: 6px;
                font-size: 13px;
                font-weight: 500;
                color: #92400E;
                margin-bottom: 16px;
              }
              .welcome-text {
                font-size: 14px;
                color: var(--text-secondary);
                margin: 16px 0;
                line-height: 1.6;
              }
              .capabilities-title {
                font-size: 14px;
                font-weight: 600;
                color: var(--text-primary);
                margin: 16px 0 8px 0;
              }
              .welcome-message ul {
                list-style: disc;
                padding-left: 20px;
                margin: 0;
              }
              .welcome-message li {
                font-size: 13px;
                color: var(--text-secondary);
                margin-bottom: 6px;
                line-height: 1.5;
              }
            </style>
            <div class='status-badge'>
              ⚡ Rflow AI Assistant Ready
            </div>
            <div class='welcome-text'>
              Type your request and I'll show you exactly what I'm doing...
            </div>
            <div class='capabilities-title'>I can help you:</div>
            <ul>
              <li>Analyze data and create visualizations</li>
              <li>Write and execute R code</li>
              <li>Read, write, and manage files</li>
              <li>Debug errors and optimize code</li>
            </ul>
          ")
        )
      ))
    }
    
    lapply(msg_list, function(msg) {
      if (msg$role == "user") {
        div(class = "message message-user",
          div(class = "message-content", HTML(msg$content))
        )
      } else {
        # Render markdown for assistant messages
        formatted_content <- render_markdown(msg$content)
        div(class = "message message-assistant",
          div(class = "message-avatar", 
            HTML('<svg fill="currentColor" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/></svg>')
          ),
          div(class = "message-content", HTML(formatted_content))
        )
      }
    })
  })
  
  # Helper function to get file icon based on extension
  get_file_icon <- function(filename) {
    ext <- tolower(tools::file_ext(filename))
    
    icons <- list(
      # Spreadsheets
      "xlsx" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #10b981;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>',
      "xls" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #10b981;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>',
      "csv" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #10b981;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>',
      # Images
      "png" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #8b5cf6;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>',
      "jpg" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #8b5cf6;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>',
      "jpeg" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #8b5cf6;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>',
      # Documents
      "pdf" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #ef4444;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path></svg>',
      "txt" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #6b7280;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>',
      # Code
      "r" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #3b82f6;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path></svg>',
      "rmd" = '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="color: #3b82f6;"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path></svg>'
    )
    
    icon <- icons[[ext]]
    if (is.null(icon)) {
      icon <- '<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path></svg>'
    }
    
    return(icon)
  }
  
  # Helper function to format file size
  format_file_size <- function(bytes) {
    if (bytes < 1024) {
      return(paste(bytes, "B"))
    } else if (bytes < 1024^2) {
      return(paste(round(bytes / 1024, 1), "KB"))
    } else if (bytes < 1024^3) {
      return(paste(round(bytes / 1024^2, 1), "MB"))
    } else {
      return(paste(round(bytes / 1024^3, 1), "GB"))
    }
  }
  
  # Handle file uploads with better preview
  output$fileAttachments <- renderUI({
    files <- uploaded_files()
    if (length(files) == 0) return(NULL)
    
    div(class = "file-attachments",
      lapply(seq_along(files), function(i) {
        file_size <- file.info(files[[i]]$path)$size
        
        div(class = "file-chip",
          div(class = "file-icon", HTML(get_file_icon(files[[i]]$name))),
          div(class = "file-info",
            span(class = "file-name", basename(files[[i]]$name)),
            span(class = "file-size", format_file_size(file_size))
          ),
          tags$span(class = "file-chip-remove", 
            onclick = sprintf("Shiny.setInputValue('removeFile', %d, {priority: 'event'})", i),
            "×"
          )
        )
      })
    )
  })
  
  # Handle file upload
  observeEvent(input$fileUpload, {
    req(input$fileUpload)
    files <- uploaded_files()
    new_files <- lapply(1:nrow(input$fileUpload), function(i) {
      list(
        name = input$fileUpload$name[i],
        path = input$fileUpload$datapath[i],
        type = input$fileUpload$type[i]
      )
    })
    uploaded_files(c(files, new_files))
  })
  
  # Handle pasted images
  observeEvent(input$pastedImage, {
    req(input$pastedImage)
    
    tryCatch({
      # Get base64 data
      base64_data <- input$pastedImage$data
      timestamp <- input$pastedImage$timestamp
      
      # Remove data URL prefix (e.g., "data:image/png;base64,")
      base64_clean <- sub("^data:image/[^;]+;base64,", "", base64_data)
      
      # Decode base64
      img_data <- base64enc::base64decode(base64_clean)
      
      # Create temporary file
      temp_file <- tempfile(pattern = paste0("pasted-image-", timestamp, "-"), fileext = ".png")
      writeBin(img_data, temp_file)
      
      # Add to uploaded files
      files <- uploaded_files()
      new_file <- list(
        name = paste0("pasted-image-", timestamp, ".png"),
        path = temp_file,
        type = "image/png"
      )
      uploaded_files(c(files, list(new_file)))
      
      cat("📎 Pasted image saved:", basename(temp_file), "\n")
    }, error = function(e) {
      cat("❌ Error saving pasted image:", conditionMessage(e), "\n")
    })
  })
  
  # Remove file
  observeEvent(input$removeFile, {
    req(input$removeFile)
    files <- uploaded_files()
    
    # Get the index to remove
    index_to_remove <- input$removeFile
    
    if (index_to_remove > 0 && index_to_remove <= length(files)) {
      # Remove the file at the specified index
      files <- files[-index_to_remove]
      uploaded_files(files)
      
      cat("Removed file at index:", index_to_remove, "\n")
      cat("Remaining files:", length(files), "\n")
      
      # If no files remain, reset the file input to clear the UI
      if (length(files) == 0) {
        shinyjs::reset("fileUpload")
        cat("All files removed, input reset\n")
      }
    }
  })
  
  # Render chat history
  output$chatHistory <- renderUI({
    sessions <- chat_sessions()
    current_id <- current_chat_id()
    
    if (length(sessions) == 0) return(NULL)
    
    lapply(sessions, function(session) {
      is_active <- session$id == current_id
      class_name <- if (is_active) "chat-history-item active" else "chat-history-item"
      
      div(
        class = class_name,
        onclick = sprintf("Shiny.setInputValue('selectChat', %d, {priority: 'event'})", session$id),
        session$title
      )
    })
  })
  
  # New Chat button
  observeEvent(input$newChatBtn, {
    sessions <- chat_sessions()
    new_id <- length(sessions) + 1
    
    # Create new chat session
    new_session <- list(
      id = new_id,
      title = "New Chat",
      messages = list(),
      timestamp = Sys.time()
    )
    
    # Add to sessions
    chat_sessions(c(sessions, list(new_session)))
    
    # Switch to new chat
    current_chat_id(new_id)
    messages(list())
    uploaded_files(list())
    
    cat("Created new chat:", new_id, "\n")
  })
  
  # Switch chat
  observeEvent(input$selectChat, {
    selected_id <- input$selectChat
    sessions <- chat_sessions()
    
    # Find the selected session
    selected_session <- sessions[[selected_id]]
    
    if (!is.null(selected_session)) {
      current_chat_id(selected_id)
      messages(selected_session$messages)
      cat("Switched to chat:", selected_id, "\n")
    }
  })
  
  # Send message
  observeEvent(input$sendBtn, {
    # Isolate to prevent reactive issues
    msg_text <- isolate(input$messageInput)
    
    # Debug output
    cat("Message input type:", class(msg_text), "\n")
    cat("Message input value:", msg_text, "\n")
    
    # Validate input
    if (is.null(msg_text) || !is.character(msg_text) || trimws(msg_text) == "") {
      cat("Input validation failed\n")
      return()
    }
    
    # Note: Inputs will be temporarily disabled by Shiny during processing
    # We use CSS to prevent the gray overlay effect
    
    # Get current messages
    current_msgs <- messages()
    
    # Add file info to message if files are attached
    files <- isolate(uploaded_files())
    if (length(files) > 0) {
      file_info <- paste0("\n\n**Attached files:**\n", 
        paste(sapply(files, function(f) paste0("- ", f$name)), collapse = "\n"))
      msg_text <- paste0(msg_text, file_info)
    }
    
    # Add user message
    current_msgs[[length(current_msgs) + 1]] <- list(
      role = "user",
      content = msg_text
    )
    messages(current_msgs)
    
    # Clear input and files
    updateTextAreaInput(session, "messageInput", value = "")
    uploaded_files(list())
    
    # Add typing indicator with professional SVG spinner
    current_msgs[[length(current_msgs) + 1]] <- list(
      role = "assistant",
      content = '<div class="typing-indicator">
        <div class="spinner-container">
          <svg class="spinner" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="12" cy="12" r="10" stroke="#0066FF" stroke-width="3" stroke-linecap="round" stroke-dasharray="31.4 31.4" stroke-dashoffset="0" opacity="0.25"/>
            <path d="M12 2 A10 10 0 0 1 22 12" stroke="#0066FF" stroke-width="3" stroke-linecap="round"/>
          </svg>
          <span class="typing-text">Thinking...</span>
        </div>
      </div>'
    )
    messages(current_msgs)
    
    # Get AI response
    cat("Starting AI request...\n")
    
    # Build message with workspace context
    user_message <- msg_text
    
    # Add workspace context for AI
    ws_folder <- isolate(workspace_folder())
    ws_files <- isolate(workspace_files())
    
    workspace_context <- ""
    if (!is.null(ws_folder) || length(ws_files) > 0) {
      workspace_context <- "\n\n--- WORKSPACE CONTEXT ---\n"
      workspace_context <- paste0(workspace_context, "The user is working in this folder. Save all files here unless specified otherwise.\n\n")
      
      if (!is.null(ws_folder)) {
        workspace_context <- paste0(workspace_context, "📁 Working Folder: ", ws_folder, "\n")
        workspace_context <- paste0(workspace_context, "📄 Total files: ", length(ws_files), "\n\n")
        
        # Get unique subfolders
        rel_paths <- gsub(paste0("^", gsub("([\\[\\]\\(\\)\\{\\}\\^\\$\\.\\*\\+\\?\\|\\\\])", "\\\\\\1", ws_folder), "/"), "", ws_files)
        subdirs <- unique(dirname(rel_paths))
        subdirs <- subdirs[subdirs != "."]
        
        if (length(subdirs) > 0) {
          workspace_context <- paste0(workspace_context, "📂 Subfolders:\n")
          for (sd in head(subdirs, 10)) {
            workspace_context <- paste0(workspace_context, "   - ", sd, "/\n")
          }
          if (length(subdirs) > 10) {
            workspace_context <- paste0(workspace_context, "   ... and ", length(subdirs) - 10, " more\n")
          }
          workspace_context <- paste0(workspace_context, "\n")
        }
        
        # Categorize files
        r_files <- ws_files[grepl("\\.(R|Rmd|rmd)$", ws_files, ignore.case = TRUE)]
        data_files <- ws_files[grepl("\\.(csv|xlsx|xls|json|rds|rda|parquet)$", ws_files, ignore.case = TRUE)]
        
        if (length(r_files) > 0) {
          workspace_context <- paste0(workspace_context, "📊 R files (", length(r_files), "):\n")
          for (rf in head(r_files, 8)) {
            workspace_context <- paste0(workspace_context, "   - ", gsub(paste0("^", ws_folder, "/"), "", rf), "\n")
          }
          if (length(r_files) > 8) {
            workspace_context <- paste0(workspace_context, "   ... and ", length(r_files) - 8, " more\n")
          }
          workspace_context <- paste0(workspace_context, "\n")
        }
        
        if (length(data_files) > 0) {
          workspace_context <- paste0(workspace_context, "📈 Data files (", length(data_files), "):\n")
          for (df in head(data_files, 8)) {
            workspace_context <- paste0(workspace_context, "   - ", gsub(paste0("^", ws_folder, "/"), "", df), "\n")
          }
          if (length(data_files) > 8) {
            workspace_context <- paste0(workspace_context, "   ... and ", length(data_files) - 8, " more\n")
          }
        }
      }
      
      workspace_context <- paste0(workspace_context, "\n--- END CONTEXT ---\n")
      cat("📁 Workspace context added to message\n")
    }
    
    # Add attached files
    if (length(files) > 0) {
      file_paths <- sapply(files, function(f) f$path)
      user_message <- paste0(user_message, "\n\nAttached files: ", paste(file_paths, collapse = ", "))
    }
    
    # Combine message with context
    user_message <- paste0(workspace_context, user_message)
    
    # Process AI request (runs in Shiny's event loop, non-blocking)
    tryCatch({
      cat("Calling client$stream...\n")

      # Stream with retry logic (3 attempts with exponential backoff)
      max_retries <- 3
      retry_count <- 0
      stream <- NULL
      last_error <- NULL

      while (retry_count < max_retries && is.null(stream)) {
        stream <- tryCatch({
          if (retry_count > 0) {
            wait_time <- 2^retry_count  # Exponential backoff: 2s, 4s, 8s
            cat(sprintf("Retry attempt %d/%d after %d seconds...\n", retry_count + 1, max_retries, wait_time))
            Sys.sleep(wait_time)
          }
          client$stream(user_message)
        }, error = function(e) {
          last_error <- e
          cat("Error creating stream (attempt ", retry_count + 1, "):", conditionMessage(e), "\n")
          retry_count <<- retry_count + 1
          NULL
        })
      }

      # If all retries failed, throw the last error
      if (is.null(stream)) {
        cat("Failed to create stream after", max_retries, "attempts\n")
        stop(last_error)
      }

      cat("Stream created, collecting chunks...\n")
      response_chunks <- character()
      chunk_count <- 0
      
      # Remove typing indicator
      current_msgs <- messages()
      current_msgs <- current_msgs[-length(current_msgs)]
      messages(current_msgs)
      
      # Add empty assistant message that we'll update in real-time
      current_msgs[[length(current_msgs) + 1]] <- list(
        role = "assistant",
        content = ""
      )
      messages(current_msgs)
      
      tryCatch({
        # Streaming configuration - Optimized for speed
        response_chunks <- vector("character", 5000)  # Larger buffer for better performance
        text_buffer <- ""  # Accumulator for real-time text
        last_update_time <- Sys.time()
        stream_start_time <- Sys.time()  # Track total streaming time
        update_interval <- 0.1  # 100ms updates (was 15ms) - less frequent = faster
        char_threshold <- 50  # Update every 50 characters (was 5) - batch more characters
        chars_since_update <- 0
        stream_timeout <- 300  # 5 minutes timeout (300 seconds)
        render_cache <- ""  # Cache last rendered content to avoid redundant renders

        # Show initial streaming status with animated cursor
        session$sendCustomMessage('showStreamingStatus', list(
          text = "AI is thinking",
          streaming = TRUE
        ))

        # Activity detection patterns (50+ activities)
        last_detected_activity <- ""
        activity_patterns <- list(
          list(pattern = "run.*code|execut.*script|evaluat", activity = "run_r_code"),
          list(pattern = "writ.*file|creat.*file|sav.*file", activity = "write_text_file"),
          list(pattern = "read.*file|load.*file|open.*file", activity = "read_text_file"),
          list(pattern = "analyz.*data|examin.*data|explor.*data", activity = "analyze_data"),
          list(pattern = "clean.*data|preprocess", activity = "clean_data"),
          list(pattern = "transform.*data|reshap.*data|manipulat", activity = "transform_data"),
          list(pattern = "visualiz|plot|chart|graph", activity = "create_plot"),
          list(pattern = "build.*model|train.*model|creat.*model", activity = "build_model"),
          list(pattern = "test.*model|validat.*model|evaluat.*model", activity = "test_model"),
          list(pattern = "fix.*error|debug|troubleshoot", activity = "fix_error"),
          list(pattern = "install.*package|load.*librar", activity = "install_package"),
          list(pattern = "check.*miss|find.*miss", activity = "check_missing"),
          list(pattern = "detect.*outlier|find.*outlier", activity = "detect_outliers"),
          list(pattern = "summar.*stat|calculat.*stat|comput.*stat", activity = "summarize_stats"),
          list(pattern = "merg.*data|join.*data|combin.*data", activity = "merge_data"),
          list(pattern = "predict|forecast", activity = "predict_outcomes"),
          list(pattern = "tune.*param|optimiz.*param", activity = "tune_parameters"),
          list(pattern = "generat.*doc|writ.*doc|document", activity = "generate_docs"),
          list(pattern = "creat.*director|make.*folder", activity = "create_directory"),
          list(pattern = "search.*file|find.*file", activity = "search_files")
        )

        coro::loop(for (chunk in stream) {
          chunk_count <- chunk_count + 1

          # Check for timeout
          elapsed_time <- as.numeric(difftime(Sys.time(), stream_start_time, units = "secs"))
          if (elapsed_time > stream_timeout) {
            cat("⏰ Stream timeout after", elapsed_time, "seconds\n")
            break  # Exit loop gracefully
          }

          if (!is.null(chunk) && nchar(chunk) > 0) {
            # Store chunk efficiently with dynamic expansion
            if (chunk_count > length(response_chunks)) {
              response_chunks <- c(response_chunks, vector("character", 1000))
            }
            response_chunks[chunk_count] <- chunk

            # Accumulate in text buffer
            text_buffer <- paste0(text_buffer, chunk)
            chars_since_update <- chars_since_update + nchar(chunk)

            # Detect activity from recent text (last 200 chars for performance)
            recent_text <- tolower(substring(text_buffer, max(1, nchar(text_buffer) - 200)))
            for (pattern_item in activity_patterns) {
              if (grepl(pattern_item$pattern, recent_text, perl = TRUE)) {
                if (last_detected_activity != pattern_item$activity) {
                  last_detected_activity <- pattern_item$activity
                  # Send activity status
                  session$sendCustomMessage('updateToolStatus', list(
                    tool = pattern_item$activity,
                    status = "running"
                  ))
                  cat("🔧 Detected activity:", pattern_item$activity, "\n")
                }
                break
              }
            }

            # Optimized update strategy for speed
            current_time <- Sys.time()
            time_diff <- as.numeric(difftime(current_time, last_update_time, units = "secs"))

            # Update conditions: ONLY time-based OR character threshold (removed chunk-based)
            should_update <- (time_diff >= update_interval || chars_since_update >= char_threshold)

            if (should_update) {
              # Only render if content changed (cache optimization)
              if (text_buffer != render_cache) {
                rendered_content <- render_markdown(text_buffer)
                render_cache <- text_buffer

                # Send incremental update with streaming flag
                session$sendCustomMessage('updateLastMessage', list(
                  content = rendered_content,
                  streaming = TRUE,
                  length = nchar(text_buffer)
                ))

                last_update_time <- current_time
                chars_since_update <- 0

                # Minimal progress logging (every 100 chunks to reduce console noise)
                if (chunk_count %% 100 == 0) {
                  cat("📝", nchar(text_buffer), "chars streamed\n")
                }
              }
            }
          }
        })

        # Trim to actual size
        response_chunks <- response_chunks[1:chunk_count]
        text_buffer <- paste(response_chunks, collapse = "")
        
      }, error = function(e) {
        error_msg <- conditionMessage(e)
        cat("Error during streaming:", error_msg, "\n")

        # Check if it's a JSON parse error
        is_parse_error <- grepl("parse error|premature EOF|invalid json", error_msg, ignore.case = TRUE)

        response_chunks <- response_chunks[1:chunk_count]
        if (chunk_count > 0) {
          cat("Partial response received (", chunk_count, "chunks), using what we have\n")
          text_buffer <- paste(response_chunks[1:chunk_count], collapse = "")

          # Add informative error message for user
          if (is_parse_error) {
            text_buffer <- paste0(text_buffer,
              "\n\n---\n\n**⚠️ Stream Interrupted**: The response was cut off due to a connection issue. ",
              "The partial response above may be incomplete. You can:",
              "\n- Ask me to continue or clarify",
              "\n- Rephrase your question",
              "\n- Try a more specific request")
          }

          # Send partial response with error indicator
          session$sendCustomMessage('updateLastMessage', list(
            content = render_markdown(text_buffer),
            streaming = FALSE,
            partial = TRUE,
            error = TRUE
          ))
        } else {
          stop(e)
        }
      })
      
      # Performance metrics
      stream_end_time <- Sys.time()
      stream_duration <- as.numeric(difftime(stream_end_time, last_update_time, units = "secs"))
      chars_per_second <- if(stream_duration > 0) round(nchar(text_buffer) / stream_duration) else 0

      cat("Total chunks received:", chunk_count, "\n")
      cat("Stream performance:", chars_per_second, "chars/sec\n")

      # Final update with complete response (use text_buffer which is already assembled)
      full_text <- text_buffer

      # Send final complete message to JavaScript with streaming = FALSE
      session$sendCustomMessage('updateLastMessage', list(
        content = render_markdown(full_text),
        streaming = FALSE,
        complete = TRUE
      ))

      # Update reactive messages for persistence
      current_msgs <- messages()
      current_msgs[[length(current_msgs)]]$content <- full_text
      messages(current_msgs)

      cat("✓ Streaming complete:", nchar(full_text), "characters in",
          round(stream_duration, 2), "seconds\n")
      
    }, error = function(e) {
      error_msg <- conditionMessage(e)
      cat("FATAL ERROR:", error_msg, "\n")
      cat("Error class:", class(e), "\n")

      # Categorize error for better user guidance
      error_category <- if (grepl("API|rate limit|quota", error_msg, ignore.case = TRUE)) {
        list(
          title = "API Error",
          suggestions = c(
            "Check your ANTHROPIC_API_KEY is valid",
            "Verify you haven't exceeded API rate limits",
            "Wait a moment and try again"
          )
        )
      } else if (grepl("network|connection|timeout", error_msg, ignore.case = TRUE)) {
        list(
          title = "Network Error",
          suggestions = c(
            "Check your internet connection",
            "Try again in a moment",
            "Simplify your request if it's very long"
          )
        )
      } else if (grepl("parse|json|EOF", error_msg, ignore.case = TRUE)) {
        list(
          title = "Stream Interrupted",
          suggestions = c(
            "The response was interrupted mid-stream",
            "Try breaking your request into smaller parts",
            "Ask me to continue from where I left off"
          )
        )
      } else {
        list(
          title = "Unexpected Error",
          suggestions = c(
            "Try rephrasing your question",
            "Check the R console for error details",
            "Restart Rflow if the issue persists: stop_rflow() then start_rflow()"
          )
        )
      }

      suggestions_html <- paste0("<br>• ", error_category$suggestions, collapse = "")

      current_msgs <- messages()
      current_msgs[[length(current_msgs)]] <- list(
        role = "assistant",
        content = paste0(
          "<strong>⚠️ ", error_category$title, "</strong>",
          "<br><br><code>", error_msg, "</code>",
          "<br><br><strong>What you can do:</strong>",
          suggestions_html
        )
      )
      messages(current_msgs)
    })
  })
  
  session$onSessionEnded(function() {
    cat("Session ended\n")
    shiny::stopApp()
  })
}

cat("Starting Shiny app...\n")

# Increase file upload size limit to 5 GB (reasonable for most use cases)
options(shiny.maxRequestSize = 5 * 1024^3)

shiny::shinyApp(ui, server)
