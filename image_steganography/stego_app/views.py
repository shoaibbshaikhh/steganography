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
