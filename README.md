# MATLAB Drilling Diagnostics Tool

Профессиональный MATLAB-инструмент для моделирования и диагностики осложнений при бурении нефтегазовых скважин.

## Возможности

- **Генерация синтетических данных**: 15 параметров бурения с физическими корреляциями
- **Моделирование осложнений**: kick, mud losses, pack-off, stuck pipe с нелинейным развитием
- **Трёхуровневая диагностика**: эвристики + инженерные расчёты + статистика
- **Фильтрация соединений**: автоматическое исключение ложных срабатываний при наращивании
- **Полный цикл**: от генерации данных до визуализации и экспорта результатов

## Быстрый старт

```matlab
cd matlab_diagnostics
run_full_diagnostics
```

## Структура проекта

```
matlab_diagnostics/
├── run_full_diagnostics.m          # Единый скрипт запуска
├── generate_synthetic_drilling.m   # Генерация данных (158 строк)
├── detect_connections.m            # Детекция соединений свечей
├── inject_complications.m          # Моделирование осложнений
├── calculate_diagnostic_features.m # Расчёт признаков (18 признаков)
├── detect_events_level1.m          # Эвристики
├── detect_events_level2.m          # Инженерные расчёты
├── detect_events_level3.m          # Статистические методы
├── aggregate_detections.m          # Агрегация результатов
├── plot_diagnostics.m              # Визуализация
├── generate_report.m               # Текстовый отчёт
└── save_results.m                  # Экспорт файлов
```

## Выходные файлы

Все результаты сохраняются в `output/`:

| Файл | Описание |
|------|----------|
| `raw_drilling_data.csv` | 480 точек × 15 параметров |
| `diagnostic_features.csv` | 18 диагностических признаков |
| `detected_events.csv` | Таблица обнаруженных осложнений |
| `drilling_diagnostics_results.mat` | Полный MATLAB workspace |
| `diagnostic_summary.txt` | Текстовый отчёт на русском |
| `diagnostic_timeseries.png` | График временных рядов |
| `risk_timeline.png` | График risk score |
| `events_for_web.json` | JSON для web-интеграции |

## Параметры бурения

MD, TVD, ROP, WOB, RPM, Torque, Hookload, SPP, FlowRate, MudWeight, ECD, PitVolume, Gas, PorePressure, FractureGradient

## Физические корреляции

- **Drill-off model**: ROP = k · WOB^a · RPM^b · lithology
- **Torque**: функция WOB и RPM
- **SPP**: функция FlowRate и глубины
- **Авторегрессионный шум** для плавности данных

## Требования

- MATLAB R2020a или новее
- Стандартные функции (без внешних библиотек)

## Лицензия

MIT
