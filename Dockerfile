FROM registry.redhat.io/ubi9/python-39@sha256:2ad08a50ddfa773d508f225a101395c271f315af88dba8ad2203f2fe22683e40

WORKDIR /app

COPY agent/ agent/
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8000

CMD ["uvicorn", "agent.main:app", "--host", "0.0.0.0", "--port", "8000"] 