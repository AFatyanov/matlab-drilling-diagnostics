function report_text = generate_report(drilling_data, final_events, conn_table)
% GENERATE_REPORT Генерация текстового отчёта на русском языке
%
% Вход:
%   drilling_data - struct с данными бурения
%   final_events  - table с событиями
%   conn_table    - table с интервалами соединений
%
% Выход:
%   report_text - string с итоговым отчётом

data = drilling_data.data;
time = drilling_data.time;

report = {};
report{end+1} = '===============================================';
report{end+1} = 'ОТЧЁТ ПО ДИАГНОСТИКЕ ОСЛОЖНЕНИЙ БУРЕНИЯ';
report{end+1} = '===============================================';
report{end+1} = '';
report{end+1} = sprintf('Дата анализа: %s', datestr(now, 'dd.mm.yyyy HH:MM'));
report{end+1} = '';

%% Общая информация
report{end+1} = '--- ОБЩАЯ ИНФОРМАЦИЯ ---';
report{end+1} = sprintf('Период симуляции: %s - %s', ...
                        datestr(time(1), 'dd.mm.yyyy HH:MM'), ...
                        datestr(time(end), 'dd.mm.yyyy HH:MM'));
report{end+1} = sprintf('Продолжительность: %.1f суток', hours(time(end)-time(1))/24);
report{end+1} = sprintf('Количество точек данных: %d', height(data));
report{end+1} = sprintf('Шаг дискретизации: 15 минут');
report{end+1} = '';

%% Параметры бурения
report{end+1} = '--- ПАРАМЕТРЫ БУРЕНИЯ ---';
report{end+1} = sprintf('Глубина MD: от %.1f до %.1f м (пробурено %.1f м)', ...
                        min(data.MD), max(data.MD), max(data.MD)-min(data.MD));
report{end+1} = sprintf('Средняя ROP: %.1f м/ч', mean(data.ROP(data.ROP>0)));
report{end+1} = sprintf('Средняя WOB: %.1f тонн', mean(data.WOB(data.WOB>0)));
report{end+1} = sprintf('Средний момент: %.1f кН·м', mean(data.Torque(data.Torque>2)));
report{end+1} = sprintf('Плотность раствора: %.2f - %.2f г/см³', ...
                        min(data.MudWeight), max(data.MudWeight));
report{end+1} = '';

%% Соединения свечей
if ~isempty(conn_table)
    report{end+1} = '--- СОЕДИНЕНИЯ СВЕЧЕЙ ---';
    report{end+1} = sprintf('Всего соединений: %d', height(conn_table));
    report{end+1} = sprintf('Средняя длительность: %.1f мин', mean(conn_table.duration_min));
    report{end+1} = sprintf('Общее время соединений: %.1f часов (%.1f%% от общего времени)', ...
                            sum(conn_table.duration_min)/60, ...
                            sum(conn_table.duration_min)/(height(data)*15)*100);
    report{end+1} = '';
end

%% Обнаруженные осложнения
report{end+1} = '--- ОБНАРУЖЕННЫЕ ОСЛОЖНЕНИЯ ---';

if isempty(final_events)
    report{end+1} = 'Осложнения не обнаружены.';
else
    report{end+1} = sprintf('Всего обнаружено событий: %d', height(final_events));
    report{end+1} = '';
    
    for i = 1:height(final_events)
        evt = final_events(i,:);
        report{end+1} = sprintf('Событие %d:', i);
        report{end+1} = sprintf('  Тип: %s', evt.event_type{1});
        report{end+1} = sprintf('  Время начала: %s', datestr(evt.start_time, 'dd.mm.yyyy HH:MM'));
        report{end+1} = sprintf('  Время окончания: %s', datestr(evt.end_time, 'dd.mm.yyyy HH:MM'));
        report{end+1} = sprintf('  Глубина MD: %.1f м', evt.start_md);
        report{end+1} = sprintf('  Risk Score: %.0f/100', evt.risk_score);
        report{end+1} = sprintf('  Уровень уверенности: %s', evt.confidence_level{1});
        report{end+1} = sprintf('  Серьёзность: %s', evt.severity{1});
        report{end+1} = sprintf('  Объяснение: %s', evt.explanation{1});
        report{end+1} = '';
    end
    
    report{end+1} = '--- СТАТИСТИКА ПО ТИПАМ ОСЛОЖНЕНИЙ ---';
    unique_types = unique(final_events.event_type);
    for i = 1:length(unique_types)
        type_count = sum(strcmp(final_events.event_type, unique_types{i}));
        report{end+1} = sprintf('%s: %d событий', unique_types{i}, type_count);
    end
    report{end+1} = '';
end

%% Улучшения в этой версии
report{end+1} = '--- УЛУЧШЕНИЯ СИСТЕМЫ ---';
report{end+1} = '✓ Фильтрация ложных срабатываний на соединениях свечей';
report{end+1} = '✓ Калиброванные пороговые значения для всех детекторов';
report{end+1} = '✓ Физические корреляции между параметрами (WOB-RPM-Torque-ROP)';
report{end+1} = '✓ Нелинейное развитие осложнений (фазы: начало-развитие-стабилизация)';
report{end+1} = '✓ Авторегрессионный шум для реалистичности данных';
report{end+1} = '✓ Обработка ошибок при сохранении файлов';
report{end+1} = '';

%% Ограничения модели
report{end+1} = '--- ОГРАНИЧЕНИЯ МОДЕЛИ ---';
report{end+1} = '1. Синтетические данные не учитывают все реальные факторы';
report{end+1} = '2. Пороговые значения требуют калибровки на реальных данных';
report{end+1} = '3. Модель не учитывает геологические осложнения';
report{end+1} = '4. Отсутствует машинное обучение для адаптации';
report{end+1} = '5. Детекторы настроены для обнаружения, а не прогнозирования';
report{end+1} = '';

%% Рекомендации
report{end+1} = '--- РЕКОМЕНДАЦИИ ПО РАЗВИТИЮ ---';
report{end+1} = '1. Калибровка на реальных данных конкретной скважины';
report{end+1} = '2. Добавление ML-моделей (Random Forest, LSTM)';
report{end+1} = '3. Расширение типов осложнений (wellbore instability, tight hole)';
report{end+1} = '4. Real-time режим обработки данных';
report{end+1} = '5. Интеграция с rigspace-pro web-интерфейсом';
report{end+1} = '';

report{end+1} = '===============================================';
report{end+1} = 'КОНЕЦ ОТЧЁТА';
report{end+1} = '===============================================';

report_text = strjoin(report, '\n');

fprintf('    Отчёт сгенерирован: %d строк\n', length(report));

end
