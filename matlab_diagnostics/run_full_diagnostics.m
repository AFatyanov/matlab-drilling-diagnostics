%% RUN_FULL_DIAGNOSTICS - Полная диагностика бурения одной командой
% Запускает весь цикл: генерация → диагностика → графики → сохранение

clear all; close all; clc;

fprintf('============================================\n');
fprintf('ПОЛНАЯ ДИАГНОСТИКА ОСЛОЖНЕНИЙ БУРЕНИЯ\n');
fprintf('============================================\n\n');

%% Шаг 1: Генерация данных
fprintf('[1/11] Генерация данных...\n');
drilling_data = generate_synthetic_drilling();

%% Шаг 2: Детекция соединений
fprintf('[2/11] Детекция соединений...\n');
[conn_mask, conn_table] = detect_connections(drilling_data);

%% Шаг 3: Моделирование осложнений
fprintf('[3/11] Моделирование осложнений...\n');
drilling_data = inject_complications(drilling_data, conn_mask);

%% Шаг 4: Расчёт признаков
fprintf('[4/11] Расчёт признаков...\n');
features_data = calculate_diagnostic_features(drilling_data, conn_mask);

%% Шаг 5: Детекция L1
fprintf('[5/11] Детекция L1 (эвристики)...\n');
events_L1 = detect_events_level1(drilling_data, features_data, conn_mask);

%% Шаг 6: Детекция L2
fprintf('[6/11] Детекция L2 (инженерные)...\n');
events_L2 = detect_events_level2(drilling_data, features_data, conn_mask);

%% Шаг 7: Детекция L3
fprintf('[7/11] Детекция L3 (статистика)...\n');
events_L3 = detect_events_level3(drilling_data, features_data, conn_mask);

%% Шаг 8: Агрегация
fprintf('[8/11] Агрегация...\n');
final_events = aggregate_detections(events_L1, events_L2, events_L3);

%% Шаг 9: Графики
fprintf('[9/11] Построение графиков...\n');
fig_handles = plot_diagnostics(drilling_data, features_data, final_events, conn_mask);

%% Шаг 10: Отчёт
fprintf('[10/11] Генерация отчёта...\n');
report_text = generate_report(drilling_data, final_events, conn_table);

%% Шаг 11: Сохранение ВСЕХ файлов
fprintf('[11/11] Сохранение результатов...\n');

output_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'output');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% CSV файлы
raw_table = drilling_data.data;
raw_table.Time = drilling_data.time;
writetable(raw_table, fullfile(output_dir, 'raw_drilling_data.csv'));

features_table = table();
features_table.Time = drilling_data.time;
fn = fieldnames(features_data);
for i = 1:length(fn)
    if isnumeric(features_data.(fn{i})) && length(features_data.(fn{i})) == length(drilling_data.time)
        features_table.(fn{i}) = features_data.(fn{i});
    end
end
writetable(features_table, fullfile(output_dir, 'diagnostic_features.csv'));

if ~isempty(final_events)
    writetable(final_events, fullfile(output_dir, 'detected_events.csv'));
else
    fid = fopen(fullfile(output_dir, 'detected_events.csv'), 'w');
    fprintf(fid, 'start_time,end_time,start_md,event_type,risk_score,confidence_level,severity,explanation\n');
    fclose(fid);
end

% MAT файл
results = struct();
results.drilling_data = drilling_data;
results.features_data = features_data;
results.final_events = final_events;
results.conn_mask = conn_mask;
results.conn_table = conn_table;
results.timestamp = datetime('now');
save(fullfile(output_dir, 'drilling_diagnostics_results.mat'), 'results');

% Текстовый отчёт
fid = fopen(fullfile(output_dir, 'diagnostic_summary.txt'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s', report_text);
fclose(fid);

% PNG графики
try
    if isfield(fig_handles, 'timeseries') && ishandle(fig_handles.timeseries)
        print(fig_handles.timeseries, fullfile(output_dir, 'diagnostic_timeseries.png'), '-dpng', '-r150');
    end
catch ME
    warning('Не удалось сохранить diagnostic_timeseries.png: %s', ME.message);
end

try
    if isfield(fig_handles, 'risk_timeline') && ishandle(fig_handles.risk_timeline)
        print(fig_handles.risk_timeline, fullfile(output_dir, 'risk_timeline.png'), '-dpng', '-r150');
    end
catch ME
    warning('Не удалось сохранить risk_timeline.png: %s', ME.message);
end

% JSON файл
try
    if ~isempty(final_events)
        js.timestamp = char(datetime('now'));
        js.total_events = height(final_events);
        ea = [];
        for i = 1:height(final_events)
            e.id = i;
            e.start_time = char(final_events.start_time(i));
            e.end_time = char(final_events.end_time(i));
            e.start_md = final_events.start_md(i);
            e.event_type = char(final_events.event_type(i));
            e.risk_score = final_events.risk_score(i);
            e.confidence_level = char(final_events.confidence_level(i));
            e.severity = char(final_events.severity(i));
            e.explanation = char(final_events.explanation(i));
            ea = [ea; e];
        end
        js.events = ea;
    else
        js.timestamp = char(datetime('now'));
        js.total_events = 0;
        js.events = [];
    end
    jt = jsonencode(js, 'PrettyPrint', true);
    fid = fopen(fullfile(output_dir, 'events_for_web.json'), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', jt);
    fclose(fid);
catch ME
    warning('Не удалось сохранить events_for_web.json: %s', ME.message);
end

%% Итог
fprintf('\n============================================\n');
fprintf('ДИАГНОСТИКА ЗАВЕРШЕНА!\n');
fprintf('============================================\n');
fprintf('Результаты: %s\n', output_dir);
fprintf('  ✓ raw_drilling_data.csv\n');
fprintf('  ✓ diagnostic_features.csv\n');
fprintf('  ✓ detected_events.csv\n');
fprintf('  ✓ drilling_diagnostics_results.mat\n');
fprintf('  ✓ diagnostic_summary.txt\n');
fprintf('  ✓ diagnostic_timeseries.png\n');
fprintf('  ✓ risk_timeline.png\n');
fprintf('  ✓ events_for_web.json\n');
fprintf('\nОбнаружено осложнений: %d\n', height(final_events));
fprintf('============================================\n');
