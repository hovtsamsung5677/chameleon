#Многоэтапный Dockerfile для MobileSAM Gradio Demo
# ===========================================
# Этап 1: Сборка
# ===========================================
FROM python:3.9-slim AS builder

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
  git \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

# Рабочая директория
WORKDIR /build

# Установка setuptools с ограничением версии (для совместимости с torch)
RUN pip install --no-cache-dir "setuptools<82" wheel

# Установка CPU-only PyTorch 1.9.0 (совместим с старыми CPU без AVX)
RUN pip install --no-cache-dir torch==1.9.0+cpu torchvision==0.10.0+cpu -f https://download.pytorch.org/whl/torch_stable.html

# Кешируем слой с зависимостями
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================================
# Этап 2: Финальный легковесный образ
# ===========================================
FROM python:3.9-slim AS runtime

# Установка только необходимых системных зависимостей
RUN apt-get update && apt-get install -y \
  libglib2.0-0 \
  libsm6 \
  libxext6 \
  libxrender1 \
  curl \
  && rm -rf /var/lib/apt/lists/*

# Рабочая директория
WORKDIR /app

# Копируем зависимости из builder-этапа
COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Копируем код приложения
COPY app/app.py .
COPY app/utils ./utils
COPY app/assets ./assets
COPY mobile_sam ./mobile_sam

# Отключаем AVX для совместимости со старыми CPU
ENV ATEN_CPU_CAPABILITY=default

# Создаем непривилегированного пользователя
RUN useradd --create-home --shell /bin/bash app && \
  chown -R app:app /app
USER app

# Экспортируем порт
EXPOSE 7860

# Запуск сервера
CMD ["python", "app.py"]