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
