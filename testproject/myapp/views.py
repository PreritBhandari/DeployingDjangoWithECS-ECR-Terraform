from django.shortcuts import render

# Create your views here.
from django.shortcuts import render
from django.http import HttpResponse

def home(request):
    return HttpResponse("Welcome to my Django App!")

def about(request):
    return HttpResponse("This is the about page.")
