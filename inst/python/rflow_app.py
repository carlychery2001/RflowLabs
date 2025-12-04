"""
Rflow PyQt6 Desktop Application
Modern Electron-style wrapper for Rflow web interface
"""

import sys
from PyQt6.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget
from PyQt6.QtWebEngineWidgets import QWebEngineView
from PyQt6.QtWebEngineCore import QWebEngineSettings, QWebEnginePage
from PyQt6.QtCore import QUrl, Qt, QSize
from PyQt6.QtGui import QIcon, QPalette, QColor


class RflowWebPage(QWebEnginePage):
    """Custom web page to handle console messages and errors"""
    
    def javaScriptConsoleMessage(self, level, message, lineNumber, sourceID):
        """Handle JavaScript console messages"""
        # Suppress console messages for cleaner output
        pass


class RflowWindow(QMainWindow):
    """Main Rflow application window - Electron-style wrapper"""
    
    def __init__(self, app_url):
        super().__init__()
        self.app_url = app_url
        
        # Window configuration
        self.setWindowTitle("Rflow AI Assistant")
        self.setGeometry(100, 100, 1100, 750)
        self.setMinimumSize(900, 600)
        
        # Set window icon (optional - can add icon file later)
        # self.setWindowIcon(QIcon("path/to/icon.png"))
        
        # Apply modern dark theme
        self.apply_modern_theme()
        
        # Create web view
        self.setup_webview()
        
        # Center window on screen
        self.center_on_screen()
        
    def apply_modern_theme(self):
        """Apply modern dark theme to window frame"""
        # Set dark palette for window chrome
        palette = QPalette()
        palette.setColor(QPalette.ColorRole.Window, QColor(45, 45, 48))
        palette.setColor(QPalette.ColorRole.WindowText, QColor(255, 255, 255))
        self.setPalette(palette)
        
        # Modern window styling
        self.setStyleSheet("""
            QMainWindow {
                background-color: #2d2d30;
            }
        """)
        
    def setup_webview(self):
        """Setup the web engine view"""
        # Create central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Create layout
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        central_widget.setLayout(layout)
        
        # Create web view
        self.web_view = QWebEngineView()
        
        # Use custom page to suppress console messages
        page = RflowWebPage(self.web_view)
        self.web_view.setPage(page)
        
        # Configure web engine settings for modern web apps
        settings = self.web_view.settings()
        settings.setAttribute(QWebEngineSettings.WebAttribute.LocalStorageEnabled, True)
        settings.setAttribute(QWebEngineSettings.WebAttribute.JavascriptEnabled, True)
        settings.setAttribute(QWebEngineSettings.WebAttribute.JavascriptCanOpenWindows, False)
        settings.setAttribute(QWebEngineSettings.WebAttribute.LocalContentCanAccessRemoteUrls, True)
        settings.setAttribute(QWebEngineSettings.WebAttribute.AllowRunningInsecureContent, True)
        settings.setAttribute(QWebEngineSettings.WebAttribute.PluginsEnabled, True)
        
        # Enable smooth scrolling
        settings.setAttribute(QWebEngineSettings.WebAttribute.ScrollAnimatorEnabled, True)
        
        # Load the Shiny app URL
        self.web_view.setUrl(QUrl(self.app_url))
        
        # Add to layout
        layout.addWidget(self.web_view)
        
        # Connect signals
        self.web_view.loadStarted.connect(self.on_load_started)
        self.web_view.loadFinished.connect(self.on_load_finished)
        
    def on_load_started(self):
        """Called when page starts loading"""
        self.setWindowTitle("Rflow AI Assistant - Loading...")
        
    def on_load_finished(self, success):
        """Called when page finishes loading"""
        if success:
            self.setWindowTitle("Rflow AI Assistant")
            # Inject custom CSS for even better styling (optional)
            self.inject_custom_styles()
        else:
            self.setWindowTitle("Rflow AI Assistant - Connection Error")
            
    def inject_custom_styles(self):
        """Inject modern UI enhancements with professional styling"""
        custom_css = """
            /* Modern scrollbars */
            ::-webkit-scrollbar {
                width: 10px;
                height: 10px;
            }
            ::-webkit-scrollbar-track {
                background: rgba(0, 0, 0, 0.1);
                border-radius: 5px;
            }
            ::-webkit-scrollbar-thumb {
                background: linear-gradient(180deg, #667eea 0%, #764ba2 100%);
                border-radius: 5px;
                border: 2px solid transparent;
                background-clip: padding-box;
            }
            ::-webkit-scrollbar-thumb:hover {
                background: linear-gradient(180deg, #5568d3 0%, #6a3f8f 100%);
                background-clip: padding-box;
            }
            
            /* Smooth animations - selective for better performance */
            button, .btn, input, textarea, select, .card, .panel {
                transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
            }
            
            a, .link {
                transition: color 0.2s ease, opacity 0.2s ease;
            }
            
            /* Modern shadows */
            .card, .panel, .box {
                box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 
                           0 2px 4px -1px rgba(0, 0, 0, 0.06);
            }
            
            /* Glassmorphism effect for containers */
            .container, .main-content {
                backdrop-filter: blur(10px);
                background: rgba(255, 255, 255, 0.95);
            }
            
            /* Modern button styles */
            button, .btn {
                border-radius: 8px;
                font-weight: 500;
                letter-spacing: 0.025em;
                box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
            }
            
            button:hover, .btn:hover {
                transform: translateY(-2px) scale(1.01);
                box-shadow: 0 6px 12px -2px rgba(0, 0, 0, 0.15);
            }
            
            button:active, .btn:active {
                transform: translateY(0) scale(0.98);
                transition-duration: 0.1s;
            }
            
            /* Modern input fields */
            input, textarea, select {
                border-radius: 8px;
                border: 1px solid rgba(0, 0, 0, 0.1);
                transition: all 0.2s ease;
            }
            
            input:focus, textarea:focus, select:focus {
                border-color: #667eea;
                box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
                outline: none;
            }
            
            /* Gradient accents */
            .accent, .highlight {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            
            /* Modern typography */
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 
                           'Helvetica Neue', Arial, sans-serif;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
            }
        """
        
        # Inject SVG icons and modern UI elements
        js_code = """
            (function() {
                // Inject custom styles
                var style = document.createElement('style');
                style.textContent = `""" + custom_css + """`;
                document.head.appendChild(style);
                
                // Add modern UI enhancements
                document.addEventListener('DOMContentLoaded', function() {
                    // Replace emoji with SVG icons if found
                    replaceEmojisWithSVG();
                    
                    // Add loading animations
                    addLoadingAnimations();
                    
                    // Enhance form elements
                    enhanceFormElements();
                });
                
                function replaceEmojisWithSVG() {
                    // Find all text nodes and replace common emojis with SVG
                    const emojiMap = {
                        '🤖': createRobotSVG(),
                        '💬': createChatSVG(),
                        '📊': createChartSVG(),
                        '⚡': createBoltSVG(),
                        '✨': createSparklesSVG(),
                        '🎨': createPaletteSVG()
                    };
                    
                    // Implementation would go here
                }
                
                function createRobotSVG() {
                    return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M12 2C10.9 2 10 2.9 10 4H14C14 2.9 13.1 2 12 2Z" fill="currentColor"/>
                        <path d="M20 7H4C2.9 7 2 7.9 2 9V19C2 20.1 2.9 21 4 21H20C21.1 21 22 20.1 22 19V9C22 7.9 21.1 7 20 7ZM9 17H7V15H9V17ZM9 13H7V11H9V13ZM17 17H15V15H17V17ZM17 13H15V11H17V13Z" fill="currentColor"/>
                    </svg>`;
                }
                
                function createChatSVG() {
                function createChatSVG() {{
                    return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M20 2H4C2.9 2 2 2.9 2 4V22L6 18H20C21.1 18 22 17.1 22 16V4C22 2.9 21.1 2 20 2Z" fill="currentColor"/>
                    </svg>`;
                }}
                
                function createChartSVG() {{
                    return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M3 13H5V21H3V13ZM7 9H9V21H7V9ZM11 5H13V21H11V5ZM15 9H17V21H15V9ZM19 13H21V21H19V13Z" fill="currentColor"/>
                    </svg>`;
                }}
                
                function createBoltSVG() {{
                    return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M13 2L3 14H12L11 22L21 10H12L13 2Z" fill="currentColor"/>
                    </svg>`;
                }}
                
                function createSparklesSVG() {{
                    return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M12 1L14.5 8.5L22 11L14.5 13.5L12 21L9.5 13.5L2 11L9.5 8.5L12 1Z" fill="currentColor"/>
                        <path d="M19 15L20 17L22 18L20 19L19 21L18 19L16 18L18 17L19 15Z" fill="currentColor"/>
                    </svg>`;
                }}
                
                function createPaletteSVG() {{
                    return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C13.66 22 15 20.66 15 19C15 18.31 14.75 17.68 14.35 17.18C13.97 16.7 13.75 16.11 13.75 15.5C13.75 14.12 14.88 13 16.25 13H18C20.21 13 22 11.21 22 9C22 5.13 17.52 2 12 2ZM6.5 12C5.67 12 5 11.33 5 10.5C5 9.67 5.67 9 6.5 9C7.33 9 8 9.67 8 10.5C8 11.33 7.33 12 6.5 12ZM9.5 8C8.67 8 8 7.33 8 6.5C8 5.67 8.67 5 9.5 5C10.33 5 11 5.67 11 6.5C11 7.33 10.33 8 9.5 8ZM14.5 8C13.67 8 13 7.33 13 6.5C13 5.67 13.67 5 14.5 5C15.33 5 16 5.67 16 6.5C16 7.33 15.33 8 14.5 8ZM17.5 12C16.67 12 16 11.33 16 10.5C16 9.67 16.67 9 17.5 9C18.33 9 19 9.67 19 10.5C19 11.33 18.33 12 17.5 12Z" fill="currentColor"/>
                    </svg>`;
                }}
                
                function addLoadingAnimations() {{
                    // Add modern shimmer effect to loading elements
                    const style = document.createElement('style');
                    style.textContent = `
                        @keyframes shimmer {{
                            0% {{ 
                                background-position: -1000px 0;
                                opacity: 0.6;
                            }}
                            50% {{
                                opacity: 1;
                            }}
                            100% {{ 
                                background-position: 1000px 0;
                                opacity: 0.6;
                            }}
                        }}
                        
                        @keyframes pulse {{
                            0%, 100% {{ 
                                opacity: 1;
                                transform: scale(1);
                            }}
                            50% {{ 
                                opacity: 0.8;
                                transform: scale(0.98);
                            }}
                        }}
                        
                        @keyframes fadeInUp {{
                            from {{
                                opacity: 0;
                                transform: translateY(20px);
                            }}
                            to {{
                                opacity: 1;
                                transform: translateY(0);
                            }}
                        }}
                        
                        .loading {{
                            background: linear-gradient(
                                90deg, 
                                rgba(240, 240, 240, 0.8) 25%, 
                                rgba(224, 224, 224, 1) 50%, 
                                rgba(240, 240, 240, 0.8) 75%
                            );
                            background-size: 1000px 100%;
                            animation: shimmer 2s ease-in-out infinite;
                            border-radius: 8px;
                        }}
                        
                        .loading-pulse {{
                            animation: pulse 2s ease-in-out infinite;
                        }}
                        
                        .fade-in-up {{
                            animation: fadeInUp 0.5s cubic-bezier(0.16, 1, 0.3, 1);
                        }}
                    `;
                    document.head.appendChild(style);
                }}
                
                function enhanceFormElements() {{
                    // Add focus rings and modern interactions
                    document.querySelectorAll('input, textarea, select, button').forEach(el => {{
                        el.style.transition = 'all 0.2s ease';
                    }});
                }}
            }})();
        """
        
        self.web_view.page().runJavaScript(js_code)
        
    def center_on_screen(self):
        """Center the window on the screen"""
        screen = QApplication.primaryScreen().geometry()
        window_geometry = self.frameGeometry()
        center_point = screen.center()
        window_geometry.moveCenter(center_point)
        self.move(window_geometry.topLeft())
        
    def closeEvent(self, event):
        """Handle window close event"""
        # Clean shutdown
        self.web_view.setUrl(QUrl("about:blank"))
        event.accept()


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python rflow_app.py <app_url>")
        print("Example: python rflow_app.py http://127.0.0.1:8080")
        sys.exit(1)
        
    app_url = sys.argv[1]
    
    # Create application
    app = QApplication(sys.argv)
    app.setApplicationName("Rflow AI Assistant")
    app.setOrganizationName("Rflow")
    
    # Set modern Fusion style
    app.setStyle('Fusion')
    
    # Apply dark theme to application
    dark_palette = QPalette()
    dark_palette.setColor(QPalette.ColorRole.Window, QColor(45, 45, 48))
    dark_palette.setColor(QPalette.ColorRole.WindowText, QColor(255, 255, 255))
    dark_palette.setColor(QPalette.ColorRole.Base, QColor(30, 30, 30))
    dark_palette.setColor(QPalette.ColorRole.AlternateBase, QColor(45, 45, 48))
    dark_palette.setColor(QPalette.ColorRole.ToolTipBase, QColor(255, 255, 255))
    dark_palette.setColor(QPalette.ColorRole.ToolTipText, QColor(255, 255, 255))
    dark_palette.setColor(QPalette.ColorRole.Text, QColor(255, 255, 255))
    dark_palette.setColor(QPalette.ColorRole.Button, QColor(45, 45, 48))
    dark_palette.setColor(QPalette.ColorRole.ButtonText, QColor(255, 255, 255))
    dark_palette.setColor(QPalette.ColorRole.Link, QColor(102, 126, 234))
    dark_palette.setColor(QPalette.ColorRole.Highlight, QColor(102, 126, 234))
    dark_palette.setColor(QPalette.ColorRole.HighlightedText, QColor(0, 0, 0))
    app.setPalette(dark_palette)
    
    # Create and show main window
    window = RflowWindow(app_url)
    window.show()
    
    # Run application
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
