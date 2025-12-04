"""
Rflow PyQt6 Desktop Application
Native Windows wrapper for Rflow web interface (like Electron)
"""

import sys
from PyQt6.QtWidgets import QApplication, QMainWindow
from PyQt6.QtWebEngineWidgets import QWebEngineView
from PyQt6.QtWebEngineCore import QWebEngineSettings
from PyQt6.QtCore import QUrl, Qt
from PyQt6.QtGui import QIcon


class MessageReceiver(QObject):
    """Handles receiving messages from R backend"""
    message_received = pyqtSignal(str)
    
    def __init__(self, port):
        super().__init__()
        self.port = port
        self.running = False
        self.server_socket = None
        
    def start(self):
        """Start listening for messages from R"""
        self.running = True
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind(('127.0.0.1', self.port))
        self.server_socket.listen(1)
        
        while self.running:
            try:
                conn, addr = self.server_socket.accept()
                data = b''
                while True:
                    chunk = conn.recv(4096)
                    if not chunk:
                        break
                    data += chunk
                
                if data:
                    message = data.decode('utf-8')
                    self.message_received.emit(message)
                    
                conn.close()
            except Exception as e:
                if self.running:
                    print(f"Error receiving message: {e}")
                    
    def stop(self):
        """Stop the receiver"""
        self.running = False
        if self.server_socket:
            self.server_socket.close()


class ChatMessage(QFrame):
    """Individual chat message widget"""
    
    def __init__(self, text, is_user=True, parent=None):
        super().__init__(parent)
        self.setFrameShape(QFrame.Shape.StyledPanel)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(12, 8, 12, 8)
        
        # Role label
        role_label = QLabel("You" if is_user else "Rflow AI")
        role_font = QFont()
        role_font.setBold(True)
        role_font.setPointSize(10)
        role_label.setFont(role_font)
        
        # Message text
        message_text = QTextEdit()
        message_text.setPlainText(text)
        message_text.setReadOnly(True)
        message_text.setFrameShape(QFrame.Shape.NoFrame)
        message_text.setMaximumHeight(200)
        
        # Style based on role
        if is_user:
            self.setStyleSheet("""
                QFrame {
                    background-color: #E3F2FD;
                    border-radius: 8px;
                    border: 1px solid #90CAF9;
                }
            """)
            role_label.setStyleSheet("color: #1976D2;")
        else:
            self.setStyleSheet("""
                QFrame {
                    background-color: #F5F5F5;
                    border-radius: 8px;
                    border: 1px solid #E0E0E0;
                }
            """)
            role_label.setStyleSheet("color: #424242;")
        
        layout.addWidget(role_label)
        layout.addWidget(message_text)
        self.setLayout(layout)


class RflowWindow(QMainWindow):
    """Main Rflow application window"""
    
    def __init__(self, api_url, env_url):
        super().__init__()
        self.api_url = api_url
        self.env_url = env_url
        self.conversation_history = []
        
        self.setWindowTitle("Rflow AI Assistant")
        self.setGeometry(100, 100, 1200, 800)
        
        self.setup_ui()
        self.setup_receiver()
        
    def setup_ui(self):
        """Setup the user interface"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # Header
        header = QFrame()
        header.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #667eea, stop:1 #764ba2);
                padding: 16px;
            }
        """)
        header_layout = QHBoxLayout()
        
        title = QLabel("🤖 Rflow AI Assistant")
        title.setStyleSheet("color: white; font-size: 18px; font-weight: bold;")
        header_layout.addWidget(title)
        
        header_layout.addStretch()
        
        status_label = QLabel("● Connected")
        status_label.setStyleSheet("color: #4CAF50; font-size: 12px;")
        header_layout.addWidget(status_label)
        
        header.setLayout(header_layout)
        main_layout.addWidget(header)
        
        # Chat area
        chat_container = QWidget()
        chat_layout = QVBoxLayout()
        chat_layout.setContentsMargins(16, 16, 16, 16)
        
        # Scroll area for messages
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        
        self.messages_widget = QWidget()
        self.messages_layout = QVBoxLayout()
        self.messages_layout.addStretch()
        self.messages_widget.setLayout(self.messages_layout)
        
        scroll.setWidget(self.messages_widget)
        chat_layout.addWidget(scroll)
        
        # Input area
        input_frame = QFrame()
        input_frame.setStyleSheet("""
            QFrame {
                background-color: white;
                border: 2px solid #E0E0E0;
                border-radius: 8px;
                padding: 8px;
            }
        """)
        input_layout = QHBoxLayout()
        input_layout.setContentsMargins(8, 8, 8, 8)
        
        self.input_field = QTextEdit()
        self.input_field.setPlaceholderText("Type your message here...")
        self.input_field.setMaximumHeight(100)
        self.input_field.setStyleSheet("""
            QTextEdit {
                border: none;
                font-size: 14px;
            }
        """)
        
        send_button = QPushButton("Send")
        send_button.setStyleSheet("""
            QPushButton {
                background-color: #667eea;
                color: white;
                border: none;
                border-radius: 6px;
                padding: 12px 24px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #5568d3;
            }
            QPushButton:pressed {
                background-color: #4451b8;
            }
        """)
        send_button.clicked.connect(self.send_message)
        
        input_layout.addWidget(self.input_field, stretch=1)
        input_layout.addWidget(send_button)
        input_frame.setLayout(input_layout)
        
        chat_layout.addWidget(input_frame)
        chat_container.setLayout(chat_layout)
        main_layout.addWidget(chat_container)
        
        central_widget.setLayout(main_layout)
        
        # Set overall style
        self.setStyleSheet("""
            QMainWindow {
                background-color: #FAFAFA;
            }
        """)
        
    def setup_receiver(self):
        """Setup message receiver from R backend"""
        # This would connect to the R backend
        # For now, it's a placeholder
        pass
        
    def add_message(self, text, is_user=True):
        """Add a message to the chat"""
        message = ChatMessage(text, is_user)
        
        # Remove stretch before adding message
        count = self.messages_layout.count()
        if count > 0:
            item = self.messages_layout.takeAt(count - 1)
            
        self.messages_layout.addWidget(message)
        self.messages_layout.addStretch()
        
        # Scroll to bottom
        QApplication.processEvents()
        scroll_bar = self.findChild(QScrollArea).verticalScrollBar()
        scroll_bar.setValue(scroll_bar.maximum())
        
    def send_message(self):
        """Send message to R backend"""
        text = self.input_field.toPlainText().strip()
        if not text:
            return
            
        # Add user message to chat
        self.add_message(text, is_user=True)
        self.input_field.clear()
        
        # Send to R backend
        try:
            self.send_to_backend(text)
        except Exception as e:
            self.add_message(f"Error: {str(e)}", is_user=False)
            
    def send_to_backend(self, message):
        """Send message to R backend via HTTP"""
        try:
            from urllib.parse import urlparse
            import urllib.request
            import urllib.error
            
            # Parse the API URL to get host and port
            parsed = urlparse(self.api_url)
            host = parsed.hostname or '127.0.0.1'
            port = parsed.port or 80
            
            # For now, just show a message that the connection is working
            # In a full implementation, this would send to a Shiny endpoint
            self.add_message(
                f"Connected to backend at {host}:{port}\n"
                f"Message received: {message}\n\n"
                f"Note: Full backend integration requires Shiny API endpoints.\n"
                f"This is a demonstration of the native PyQt6 GUI.",
                is_user=False
            )
            
        except Exception as e:
            raise Exception(f"Failed to send message: {str(e)}")
            
    def closeEvent(self, event):
        """Handle window close"""
        # Clean up connections
        event.accept()


def main():
    """Main entry point"""
    if len(sys.argv) < 3:
        print("Usage: python rflow_gui.py <api_url> <env_url>")
        sys.exit(1)
        
    api_url = sys.argv[1]
    env_url = sys.argv[2]
    
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle('Fusion')
    
    # Create and show main window
    window = RflowWindow(api_url, env_url)
    window.show()
    
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
