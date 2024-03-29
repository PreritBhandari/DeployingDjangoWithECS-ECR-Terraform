FROM python:3.9

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app/

# Install gunicorn (added this line to install gunicorn)
RUN pip install gunicorn

EXPOSE 8000

# CMD ["gunicorn","--bind", "0.0.0.0:8000","testproject.wsgi:application"]

CMD ["python", "testproject/manage.py", "runserver", "0.0.0.0:8000"]

