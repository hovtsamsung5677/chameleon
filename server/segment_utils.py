"""
Вспомогательные функции для сегментации объектов с MobileSAM.
"""

import os
import sys
import time
import urllib.request
from pathlib import Path
from typing import Optional, Tuple

import numpy as np
import torch
from PIL import Image

# Оптимизация для старых CPU: ограничиваем количество потоков
torch.set_num_threads(2)
print(f"PyTorch threads set to: {torch.get_num_threads()}")

# Импорты MobileSAM с несколькими вариантами для совместимости
_sam_import_error = None
_sam_model_registry = None
_SamPredictor = None

try:
    from mobile_sam import sam_model_registry, SamPredictor
    _sam_model_registry = sam_model_registry
    _SamPredictor = SamPredictor
except ImportError as e:
    _sam_import_error = e
    try:
        # Альтернативный путь (может быть в site-packages или при запуске из Docker)
        import site
        site_packages = site.getsitepackages()
        for sp in site_packages:
            sys.path.insert(0, sp)
        from mobile_sam import sam_model_registry, SamPredictor
        _sam_model_registry = sam_model_registry
        _SamPredictor = SamPredictor
    except ImportError as e2:
        _sam_import_error = e2

if _sam_model_registry is None or _SamPredictor is None:
    raise ImportError(
        f"MobileSAM не установлен или не может быть импортирован.\n"
        f"Попробуйте установить: pip install git+https://github.com/ChaoningZhang/MobileSAM.git\n"
        f"Оригинальная ошибка: {_sam_import_error}"
    )

# Глобальная переменная для хранения загруженного предиктора
_predictor = None
_device = None


def get_device() -> str:
    """Определяет доступное устройство (cuda или cpu) с учетом переменной окружения."""
    # Проверяем переменную окружения DEVICE
    env_device = os.environ.get('DEVICE', '').lower()
    if env_device in ('cuda', 'gpu'):
        if torch.cuda.is_available():
            return "cuda"
        else:
            print(
                "Предупреждение: CUDA запрошена через DEVICE, но не доступна. Используется CPU.")
            return "cpu"
    elif env_device == 'cpu':
        return 'cpu'
    else:
        # Автоматическое определение
        return "cuda" if torch.cuda.is_available() else "cpu"


def download_weights(weights_path: str = "weights/mobile_sam.pt") -> str:
    """
    Скачивает веса MobileSAM если они отсутствуют.

    Args:
        weights_path: Путь к файлу весов

    Returns:
        Путь к файлу весов
    """
    weights_file = Path(weights_path)
    weights_file.parent.mkdir(parents=True, exist_ok=True)

    if not weights_file.exists():
        print(f"Скачивание весов MobileSAM в {weights_path}...")
        url = "https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt"
        try:
            urllib.request.urlretrieve(url, weights_path)
            print("Веса успешно скачаны.")
        except Exception as e:
            raise RuntimeError(f"Не удалось скачать веса модели с {url}: {e}")
    else:
        print(f"Веса найдены в {weights_path}")

    return str(weights_file)


def load_model(model_type: str = "vit_t", device: Optional[str] = None):
    """
    Загружает модель MobileSAM и создает предиктор.
    Модель кэшируется для повторного использования.

    Args:
        model_type: Тип модели (vit_t для MobileSAM)
        device: Устройство для инференса ('cuda' или 'cpu')

    Returns:
        SamPredictor: Готовый предиктор для сегментации
    """
    global _predictor, _device

    if _predictor is not None:
        return _predictor

    if device is None:
        device = get_device()

    print(f"Загрузка модели MobileSAM на устройство: {device}")
    print(f"Using {torch.get_num_threads()} threads for inference")

    # Скачиваем веса если нужно
    weights_path = download_weights()

    # Загружаем модель
    mobile_sam = sam_model_registry[model_type](checkpoint=weights_path)
    mobile_sam.to(device=device)
    mobile_sam.eval()

    # Попытка JIT-компиляции для ускорения (только для CPU)
    if device == "cpu":
        try:
            print("Attempting JIT optimization for CPU...")
            # MobileSAM использует TinyViT, который сложно трассировать
            # Пробуем torch.jit.script, но отключаем если не работает
            # mobile_sam = torch.jit.script(mobile_sam)
            # print("Model JIT compiled successfully")
        except Exception as e:
            print(f"JIT optimization skipped: {e}")

    # Создаем предиктор
    _predictor = SamPredictor(mobile_sam)
    _device = device

    print(f"Модель MobileSAM успешно загружена на {device}")
    return _predictor


def preprocess_image(image_bytes: bytes) -> np.ndarray:
    """
    Преобразует байты изображения в numpy array в формате RGB.

    Args:
        image_bytes: Байты изображения

    Returns:
        np.ndarray: Изображение в формате (H, W, 3), RGB
    """
    from io import BytesIO

    # Загружаем изображение через PIL
    image = Image.open(BytesIO(image_bytes)).convert("RGB")

    # Конвертируем в numpy array
    image_array = np.array(image)

    return image_array


def rle_encode(mask: np.ndarray) -> dict:
    """
    Кодирует бинарную маску в RLE (Run-Length Encoding) в формате COCO.
    counts всегда начинается с фона (0), затем объект (1), чередуясь.

    Args:
        mask: Бинарная маска (H, W) или (H, W, 1)

    Returns:
        dict: Словарь с ключами 'counts' и 'size'
    """
    if mask.ndim == 3:
        mask = mask.squeeze(-1)

    # Используем row-major (C-style) порядок для совместимости с Dart/Flutter
    flat_mask = mask.flatten(order="C").astype(np.int8)

    counts = []
    current_val = 0  # начинаем с фона (0)
    current_count = 0

    for pixel in flat_mask:
        if pixel == current_val:
            current_count += 1
        else:
            counts.append(current_count)
            current_count = 1
            current_val = pixel

    counts.append(current_count)

    return {
        "counts": [int(c) for c in counts],
        "size": [int(mask.shape[0]), int(mask.shape[1])]
    }


def rle_decode(rle: dict) -> np.ndarray:
    """
    Декодирует RLE маску в бинарную маску.
    Совместимо с COCO RLE: counts начинается с фона (0).

    Args:
        rle: Словарь с ключами 'counts' и 'size'

    Returns:
        np.ndarray: Бинарная маска (H, W)
    """
    h, w = rle["size"]
    mask = np.zeros(h * w, dtype=np.uint8)

    if not rle["counts"]:
        return mask.reshape(h, w)

    counts = rle["counts"]
    idx = 0
    val = 0  # Начинаем с фона (0)

    for count in counts:
        mask[idx:idx + count] = val
        idx += count
        val = 1 - val  # Меняем 0<->1

    # Используем row-major (C-style) порядок для совместимости с Dart/Flutter
    return mask.reshape(h, w, order="C")


def segment_image(
    image_array: np.ndarray,
    point_x: float,
    point_y: float,
    point_label: int = 1,
    device: Optional[str] = None
) -> Tuple[np.ndarray, Optional[list]]:
    """
    Выполняет сегментацию изображения по точке.

    Args:
        image_array: Изображение в формате (H, W, 3), RGB
        point_x: Координата X точки (пиксели)
        point_y: Координата Y точки (пиксели)
        point_label: Метка точки (1 - foreground, 0 - background)
        device: Устройство для инференса

    Returns:
        Tuple[np.ndarray, Optional[list]]: (маска, bbox в формате [x1,y1,x2,y2])
    """
    start_time = time.time()
    
    # Загружаем модель
    predictor = load_model(device=device)

    # Устанавливаем изображение
    predictor.set_image(image_array)

    # Подготавливаем точки
    input_point = np.array([[point_x, point_y]])
    input_label = np.array([point_label])

    # Получаем маски
    masks, scores, logits = predictor.predict(
        point_coords=input_point,
        point_labels=input_label,
        multimask_output=False  # Возвращаем только лучшую маску
    )

    mask = masks[0]  # (H, W) boolean

    # Вычисляем bounding box
    if mask.any():
        y_indices, x_indices = np.where(mask)
        x_min, x_max = x_indices.min(), x_indices.max()
        y_min, y_max = y_indices.min(), y_indices.max()
        bbox = [int(x_min), int(y_min), int(x_max), int(y_max)]
    else:
        bbox = None

    elapsed = time.time() - start_time
    print(f"Segmentation took {elapsed:.2f} seconds")
    
    return mask.astype(np.uint8), bbox
