#!/bin/bash

# Image Steganography Project Setup Script
# This script automates the setup process for the Image Steganography Django web application

# Color codes for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print colored messages
function print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

function print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

function print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3 and try again."
    exit 1
fi

print_info "Creating project directory: image_steganography"
mkdir -p image_steganography
cd image_steganography

# Create virtual environment
print_info "Creating virtual environment..."
python3 -m venv venv
if [ $? -ne 0 ]; then
    print_error "Failed to create virtual environment. Please make sure python3-venv is installed."
    exit 1
fi

# Activate virtual environment
case "$(uname -s)" in
    Linux*|Darwin*)
        print_info "Activating virtual environment (Linux/macOS)..."
        source venv/bin/activate
        ;;
    CYGWIN*|MINGW*|MSYS*)
        print_info "Activating virtual environment (Windows)..."
        source venv/Scripts/activate
        ;;
    *)
        print_error "Unsupported operating system. Please activate the virtual environment manually."
        exit 1
        ;;
esac

# Create requirements.txt
print_info "Creating requirements.txt file..."
cat > requirements.txt << 'EOL'
Django==4.2.7
opencv-python==4.8.0.76
numpy==1.24.3
Pillow==10.0.0
EOL

# Install requirements
print_info "Installing required packages..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    print_error "Failed to install requirements. Please check your internet connection and try again."
    exit 1
fi

# Create Django project
print_info "Creating Django project..."
django-admin startproject stego_project .
if [ $? -ne 0 ]; then
    print_error "Failed to create Django project."
    exit 1
fi

# Create Django app
print_info "Creating Django app..."
python manage.py startapp stego_app
if [ $? -ne 0 ]; then
    print_error "Failed to create Django app."
    exit 1
fi

# Create directory structure
print_info "Creating directory structure..."
mkdir -p stego_app/templates/stego_app
mkdir -p media/temp

# Create settings.py
print_info "Configuring settings.py..."
cat > stego_project/settings.py << 'EOL'
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'django-insecure-your-secret-key-here'

DEBUG = True

ALLOWED_HOSTS = []

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'stego_app',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'stego_project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'stego_project.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOL

# Create project urls.py
print_info "Creating project urls.py..."
cat > stego_project/urls.py << 'EOL'
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('stego_app.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
EOL

# Create app urls.py
print_info "Creating app urls.py..."
cat > stego_app/urls.py << 'EOL'
from django.urls import path
from . import views

app_name = 'stego_app'

urlpatterns = [
    path('', views.home, name='home'),
    path('encode/', views.encode, name='encode'),
    path('encode_image/', views.encode_image, name='encode_image'),
    path('decode/', views.decode, name='decode'),
    path('decode_image/', views.decode_image, name='decode_image'),
]
EOL

# Create views.py
print_info "Creating views.py..."
cat > stego_app/views.py << 'EOL'
import os
import cv2
import numpy as np
from PIL import Image
from io import BytesIO

from django.shortcuts import render, redirect
from django.http import HttpResponse, FileResponse
from django.core.files.storage import FileSystemStorage
from django.contrib import messages
from django.conf import settings

def home(request):
    return render(request, 'stego_app/home.html')

def encode(request):
    return render(request, 'stego_app/encode.html')

def decode(request):
    return render(request, 'stego_app/decode.html')

def encode_to_image(img, message):
    # Convert message to binary
    binary_message = ''.join(format(ord(char), '08b') for char in message)
    binary_message += '1111111111111110'  # Delimiter to mark end of message
    
    # Flatten the image
    flat_img = img.reshape(-1)
    
    # Check if image has enough pixels to hide the message
    if len(binary_message) > len(flat_img):
        return None, "Message too large for this image"
    
    # Embed the message
    for i, bit in enumerate(binary_message):
        # Set the LSB of each pixel to the message bit
        flat_img[i] = (flat_img[i] & ~1) | int(bit)
    
    # Reshape back to original dimensions
    stego_img = flat_img.reshape(img.shape)
    return stego_img, None

def decode_from_image(img):
    # Flatten the image
    flat_img = img.reshape(-1)
    
    # Extract LSB from each pixel
    binary_message = ''
    for i in range(len(flat_img)):
        binary_message += str(flat_img[i] & 1)
        
        # Check for the delimiter
        if len(binary_message) >= 16 and binary_message[-16:] == '1111111111111110':
            binary_message = binary_message[:-16]  # Remove the delimiter
            break
    
    # Convert binary to ASCII
    message = ''
    for i in range(0, len(binary_message), 8):
        if i + 8 > len(binary_message):
            break
        byte = binary_message[i:i+8]
        message += chr(int(byte, 2))
    
    return message

def encode_image(request):
    if request.method == 'POST' and request.FILES.get('image'):
        # Get the uploaded image
        image_file = request.FILES['image']
        message = request.POST.get('message', '')
        
        if not message:
            messages.error(request, 'No message provided for hiding.')
            return redirect('stego_app:encode')
        
        # Save the uploaded image temporarily
        fs = FileSystemStorage(location=os.path.join(settings.MEDIA_ROOT, 'temp'))
        filename = fs.save(image_file.name, image_file)
        image_path = os.path.join(settings.MEDIA_ROOT, 'temp', filename)
        
        # Process the image
        try:
            # Read the image using OpenCV
            img = cv2.imread(image_path)
            if img is None:
                messages.error(request, 'Failed to read the image. Please try another format (e.g., PNG, JPG).')
                os.remove(image_path)
                return redirect('stego_app:encode')
            
            # Encode the message
            stego_img, error = encode_to_image(img, message)
            if error:
                messages.error(request, error)
                os.remove(image_path)
                return redirect('stego_app:encode')
            
            # Save the steganographic image
            output_path = os.path.join(settings.MEDIA_ROOT, 'encoded_' + filename)
            cv2.imwrite(output_path, stego_img)
            
            # Clean up the temporary file
            os.remove(image_path)
            
            # Serve the file for download
            response = FileResponse(open(output_path, 'rb'), as_attachment=True, filename='encoded_' + image_file.name)
            return response
            
        except Exception as e:
            messages.error(request, f'Error processing image: {str(e)}')
            if os.path.exists(image_path):
                os.remove(image_path)
            return redirect('stego_app:encode')
    
    messages.error(request, 'No image uploaded.')
    return redirect('stego_app:encode')

def decode_image(request):
    if request.method == 'POST' and request.FILES.get('image'):
        # Get the uploaded image
        image_file = request.FILES['image']
        
        # Save the uploaded image temporarily
        fs = FileSystemStorage(location=os.path.join(settings.MEDIA_ROOT, 'temp'))
        filename = fs.save(image_file.name, image_file)
        image_path = os.path.join(settings.MEDIA_ROOT, 'temp', filename)
        
        # Process the image
        try:
            # Read the image using OpenCV
            img = cv2.imread(image_path)
            if img is None:
                messages.error(request, 'Failed to read the image. Please try another format (e.g., PNG, JPG).')
                os.remove(image_path)
                return redirect('stego_app:decode')
            
            # Decode the message
            message = decode_from_image(img)
            
            # Clean up the temporary file
            os.remove(image_path)
            
            if not message:
                messages.warning(request, 'No hidden message found in the image.')
                return redirect('stego_app:decode')
            
            # Pass the decoded message to the template
            return render(request, 'stego_app/decode.html', {'decoded_message': message})
            
        except Exception as e:
            messages.error(request, f'Error processing image: {str(e)}')
            if os.path.exists(image_path):
                os.remove(image_path)
            return redirect('stego_app:decode')
    
    messages.error(request, 'No image uploaded.')
    return redirect('stego_app:decode')
EOL

# Create HTML templates
print_info "Creating base.html template..."
cat > stego_app/templates/stego_app/base.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Steganography Tool</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {
            background-color: #f8f9fa;
            padding-top: 20px;
        }
        .navbar {
            margin-bottom: 20px;
        }
        .card {
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .card-header {
            background-color: #343a40;
            color: white;
        }
        .footer {
            margin-top: 50px;
            padding: 20px 0;
            background-color: #343a40;
            color: white;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
            <div class="container-fluid">
                <a class="navbar-brand" href="{% url 'stego_app:home' %}">Steganography Tool</a>
                <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
                    <span class="navbar-toggler-icon"></span>
                </button>
                <div class="collapse navbar-collapse" id="navbarNav">
                    <ul class="navbar-nav">
                        <li class="nav-item">
                            <a class="nav-link" href="{% url 'stego_app:home' %}">Home</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="{% url 'stego_app:encode' %}">Encode</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="{% url 'stego_app:decode' %}">Decode</a>
                        </li>
                    </ul>
                </div>
            </div>
        </nav>

        {% if messages %}
            <div class="messages">
                {% for message in messages %}
                    <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
                        {{ message }}
                        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                    </div>
                {% endfor %}
            </div>
        {% endif %}

        {% block content %}{% endblock %}
    </div>

    <footer class="footer">
        <div class="container">
            <p>Image Steganography Tool - Ethical Hacking Project</p>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOL

print_info "Creating home.html template..."
cat > stego_app/templates/stego_app/home.html << 'EOL'
{% extends 'stego_app/base.html' %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-md-8">
        <div class="card">
            <div class="card-header">
                <h2>Image Steganography Tool</h2>
            </div>
            <div class="card-body">
                <h4>Welcome to the Image Steganography Tool</h4>
                <p>
                    Steganography is the practice of concealing a message within another message or a physical object.
                    In this case, we hide text messages within images by slightly modifying pixel values.
                </p>
                <p>
                    This tool allows you to:
                </p>
                <ul>
                    <li>Hide secret messages within image files</li>
                    <li>Extract hidden messages from steganographic images</li>
                </ul>
                
                <div class="row mt-4">
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-body text-center">
                                <h5 class="card-title">Encode a Message</h5>
                                <p class="card-text">Hide your secret message inside an image.</p>
                                <a href="{% url 'stego_app:encode' %}" class="btn btn-primary">Encode Message</a>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-body text-center">
                                <h5 class="card-title">Decode a Message</h5>
                                <p class="card-text">Extract a hidden message from an image.</p>
                                <a href="{% url 'stego_app:decode' %}" class="btn btn-success">Decode Message</a>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="mt-4">
                    <h5>How It Works:</h5>
                    <p>
                        The tool uses the Least Significant Bit (LSB) technique:
                    </p>
                    <ol>
                        <li>Each character of your message is converted to its binary representation</li>
                        <li>Each bit of the binary message replaces the least significant bit of a pixel's color value</li>
                        <li>These small changes are imperceptible to the human eye but can be decoded by the tool</li>
                    </ol>
                    <p>
                        For ethical use only. Always respect privacy and intellectual property rights.
                    </p>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOL

print_info "Creating encode.html template..."
cat > stego_app/templates/stego_app/encode.html << 'EOL'
{% extends 'stego_app/base.html' %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-md-8">
        <div class="card">
            <div class="card-header">
                <h2>Encode Secret Message</h2>
            </div>
            <div class="card-body">
                <p>Upload an image and enter a message to hide within it. The tool will create a new image with your message hidden inside.</p>
                
                <form method="post" action="{% url 'stego_app:encode_image' %}" enctype="multipart/form-data">
                    {% csrf_token %}
                    <div class="mb-3">
                        <label for="image" class="form-label">Select Image</label>
                        <input type="file" class="form-control" id="image" name="image" accept="image/*" required>
                        <div class="form-text">Recommended formats: PNG, BMP, TIFF (lossless formats work best)</div>
                    </div>
                    <div class="mb-3">
                        <label for="message" class="form-label">Secret Message</label>
                        <textarea class="form-control" id="message" name="message" rows="5" required></textarea>
                    </div>
                    <div class="d-grid gap-2">
                        <button type="submit" class="btn btn-primary">Hide Message</button>
                    </div>
                </form>
                
                <div class="mt-4">
                    <h5>Tips:</h5>
                    <ul>
                        <li>Larger images can store longer messages</li>
                        <li>Use lossless image formats (PNG, BMP) for best results</li>
                        <li>The resulting image will look identical to the original</li>
                        <li>Keep your encoded images secure - anyone with this tool can extract hidden messages</li>
                    </ul>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOL

print_info "Creating decode.html template..."
cat > stego_app/templates/stego_app/decode.html << 'EOL'
{% extends 'stego_app/base.html' %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-md-8">
        <div class="card">
            <div class="card-header">
                <h2>Decode Hidden Message</h2>
            </div>
            <div class="card-body">
                <p>Upload an image that contains a hidden message. The tool will extract and display the message.</p>
                
                {% if decoded_message %}
                    <div class="alert alert-success">
                        <h5>Decoded Message:</h5>
                        <div class="p-3 border rounded bg-light">
                            <pre style="white-space: pre-wrap; word-break: break-word;">{{ decoded_message }}</pre>
                        </div>
                    </div>
                {% endif %}
                
                <form method="post" action="{% url 'stego_app:decode_image' %}" enctype="multipart/form-data">
                    {% csrf_token %}
                    <div class="mb-3">
                        <label for="image" class="form-label">Select Image with Hidden Message</label>
                        <input type="file" class="form-control" id="image" name="image" accept="image/*" required>
                    </div>
                    <div class="d-grid gap-2">
                        <button type="submit" class="btn btn-success">Extract Message</button>
                    </div>
                </form>
                
                <div class="mt-4">
                    <h5>Notes:</h5>
                    <ul>
                        <li>Only images created with this tool can be decoded correctly</li>
                        <li>If the image was modified after encoding (resized, recompressed, etc.), the message may be lost</li>
                        <li>If no message is found, you'll be notified</li>
                    </ul>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOL

# Run database migrations
print_info "Running database migrations..."
python manage.py makemigrations
python manage.py migrate

# Create a README file
print_info "Creating README.md file..."
cat > README.md << 'EOL'
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
EOL

# Make the script executable
print_info "Making the setup script executable..."
cat > run.sh << 'EOL'
#!/bin/bash

# Activate virtual environment
case "$(uname -s)" in
    Linux*|Darwin*)
        source venv/bin/activate
        ;;
    CYGWIN*|MINGW*|MSYS*)
        source venv/Scripts/activate
        ;;
    *)
        echo "Unable to detect OS for virtual environment activation. Please activate it manually."
        exit 1
        ;;
esac

# Start Django development server
python manage.py runserver
EOL

chmod +x run.sh

print_success "Setup completed successfully!"
print_info "To start the application, run the following command:"
echo ""
print_info "  ./run.sh"
echo ""
print_info "Then open your web browser and navigate to http://127.0.0.1:8000/"
print_info "NOTE: Make sure you remain in the virtual environment (you'll see (venv) at the beginning of your prompt)."
echo ""
print_warning "For production deployment, make sure to update SECRET_KEY and set DEBUG = False in settings.py"