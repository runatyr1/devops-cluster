FROM python:3.11-slim as builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Runtime stage
FROM gcr.io/distroless/python3:nonroot

WORKDIR /app
COPY --from=builder /app /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

ENV PYTHONPATH=/usr/local/lib/python3.11/site-packages
ENV PORT=8080

USER nonroot
EXPOSE 8080
ENTRYPOINT ["python3.11"]
CMD ["/app/app.py"]