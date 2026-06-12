%% MATLAB Drilling Diagnostics Tool
% Главный скрипт для запуска диагностики осложнений бурения
% Автор: Система диагностики бурения
% Дата: 2026-06-12

clear all; close all; clc;

fprintf('=== MATLAB Drilling Diagnostics Tool ===\n');
fprintf('Запуск диагностики осложнений бурения...\n\n');

%% Шаг 1: Генерация синтетических данных
fprintf('[1/10] Генерация синтетических данных бурения...\n');
drilling_data = generate_synthetic_drilling();
fprintf('      Сгенерировано %d временных точек\n', height(drilling_data.data));

%% Шаг 2: Моделирование осложнений
fprintf('[2/10] Моделирование осложнений...\n');
drilling_data = inject_complications(drilling_data);
fprintf('      Смоделировано %d осложнений\n', height(drilling_data.complications_ground_truth));

%% Шаг 3: Расчёт диагностических признаков
fprintf('[3/10] Расчёт диагностических признаков...\n');
features_data = calculate_diagnostic_features(drilling_data);
fprintf('      Рассчитано %d диагностических признаков\n', length(fieldnames(features_data)));

%% Шаг 4: Детекция уровня 1 - Эвристики
fprintf('[4/10] Обнаружение осложнений - Уровень 1 (эвристики)...\n');
events_L1 = detect_events_level1(drilling_data, features_data);
fprintf('      Обнаружено событий: %d\n', height(events_L1));

%% Шаг 5: Детекция уровня 2 - Инженерные расчёты
fprintf('[5/10] Обнаружение осложнений - Уровень 2 (инженерные расчёты)...\n');
events_L2 = detect_events_level2(drilling_data, features_data);
fprintf('      Обнаружено событий: %d\n', height(events_L2));

%% Шаг 6: Детекция уровня 3 - Статистика
fprintf('[6/10] Обнаружение осложнений - Уровень 3 (статистика)...\n');
events_L3 = detect_events_level3(drilling_data, features_data);
fprintf('      Обнаружено событий: %d\n', height(events_L3));

%% Шаг 7: Агрегация результатов
fprintf('[7/10] Агрегация результатов диагностики...\n');
final_events = aggregate_detections(events_L1, events_L2, events_L3);
fprintf('      Итого событий после агрегации: %d\n', height(final_events));

%% Шаг 8: Построение графиков
fprintf('[8/10] Построение диагностических графиков...\n');
fig_handles = plot_diagnostics(drilling_data, features_data, final_events);
fprintf('      Создано графиков: %d\n', length(fieldnames(fig_handles)));

%% Шаг 9: Генерация отчёта
fprintf('[9/10] Генерация текстового отчёта...\n');
report_text = generate_report(drilling_data, final_events);
fprintf('      Отчёт сгенерирован, размер: %d символов\n', length(report_text));

%% Шаг 10: Сохранение результатов
fprintf('[10/10] Сохранение результатов...\n');
save_results(drilling_data, features_data, final_events, fig_handles, report_text);
fprintf('       Результаты сохранены в папку output/\n\n');

fprintf('=== Диагностика завершена успешно! ===\n');
fprintf('Проверьте результаты в папке matlab_diagnostics/output/\n');
