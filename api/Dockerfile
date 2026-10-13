FROM python:3.14-slim
WORKDIR /srv
COPY pyproject.toml ./
RUN pip install --no-cache-dir .
COPY . .
RUN pip install --no-cache-dir -e .
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
