function report_text = generate_report(drilling_data, final_events, conn_table, complications)
% GENERATE_REPORT Генерация текстового отчёта на русском языке
%
% Вход:
%   drilling_data - struct с данными бурения
%   final_events - table с событиями
%   conn_table - table с интервалами соединений
%   complications - таблица физических осложнений
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

%% Физические осложнения
if ~isempty(complications)
    report{end+1} = '--- ФИЗИЧЕСКИЕ ОСЛОЖНЕНИЯ (триггеры) ---';
    report{end+1} = sprintf('Сработало осложнений: %d', height(complications));
    for i = 1:height(complications)
        comp = complications(i, :);
        report{end+1} = sprintf('  %d. %s (%s) - тяжесть: %.0f%%', ...
            i, comp.type{1}, comp.mechanism{1}, comp.severity);
    end
    report{end+1} = '';
end

%% Обнаруженные осложнения
report{end+1} = '--- ОБНАРУЖЕННЫЕ ОСЛОЖНЕНИЯ (детекторы) ---';

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

%% Улучшения системы
report{end+1} = '--- УЛУЧШЕНИЯ СИСТЕМЫ (v2.0 - Physics-Driven) ---';
report{end+1} = '✓ Физическая модель пластов с литологией и градиентами давления';
report{end+1} = '✓ Расчёт гидравлики и ECD через annular pressure loss';
report{end+1} = '✓ Механическая удельная энергия (MSE) для оценки эффективности бурения';
report{end+1} = '✓ Модель очистки ствола с расчётом cuttings load и packoff index';
report{end+1} = '✓ Причинные триггеры осложнений на основе физических условий';
report{end+1} = '✓ Разделение stuck pipe на механический и дифференциальный';
report{end+1} = '✓ Взвешенная модель risk score с учётом физической тяжести';
report{end+1} = '✓ Физические объяснения в отчёте (ECD, pressure margins, cuttings transport)';
report{end+1} = '✓ Фильтрация ложных срабатываний на соединениях свечей';
report{end+1} = '';

%% Ограничения модели
report{end+1} = '--- ОГРАНИЧЕНИЯ МОДЕЛИ ---';
report{end+1} = '1. Синтетические данные не учитывают все реальные факторы';
report{end+1} = '2. Упрощённая гидравлика (эмпирические коэффициенты)';
report{end+1} = '3. Модель не учитывает геологические осложнения (wellbore instability)';
report{end+1} = '4. Отсутствует машинное обучение для адаптации';
report{end+1} = '5. Детекторы настроены для обнаружения, а не прогнозирования';
report{end+1} = '';

%% Рекомендации
report{end+1} = '--- РЕКОМЕНДАЦИИ ПО РАЗВИТИЮ ---';
report{end+1} = '1. Калибровка гидравлических коэффициентов на реальных данных';
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
