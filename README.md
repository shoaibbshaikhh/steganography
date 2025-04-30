# Image Steganography Tool

This is a Django web application for image steganography - hiding secret messages within images.

## Features

- Hide text messages in images using the LSB (Least Significant Bit) technique
- Extract hidden messages from steganographic images
- User-friendly web interface
- Secure file handling

## Setup

1. Clone the repository
2. Make sure you have Python 3.8+ installed
3. Run the setup script:
   ```
   chmod +x setup.sh
   ./setup.sh
   ```

## Usage

1. Start the Django development server:
   ```
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   python manage.py runserver
   ```

2. Open your web browser and navigate to http://127.0.0.1:8000/

3. Use the web interface to encode messages into images or decode messages from images.

## Notes

- This tool is for educational and ethical purposes only
- Use PNG or other lossless image formats for best results
- The steganography method used is not cryptographically secure
