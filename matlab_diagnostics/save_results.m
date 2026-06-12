function save_results(drilling_data, features_data, final_events, fig_handles, report_text)
% SAVE_RESULTS Сохранение всех результатов диагностики
%
% Входные данные:
%   drilling_data - struct с данными бурения
%   features_data - struct с признаками
%   final_events - table с событиями
%   fig_handles - struct с графиками
%   report_text - текстовый отчёт

%% Создание директории output
output_dir = 'output';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% 1. Сохранение raw_drilling_data.csv
fprintf('    Сохранение raw_drilling_data.csv...\n');
raw_table = drilling_data.data;
raw_table.Time = drilling_data.time;
writetable(raw_table, fullfile(output_dir, 'raw_drilling_data.csv'));

%% 2. Сохранение diagnostic_features.csv
fprintf('    Сохранение diagnostic_features.csv...\n');
features_table = table();
features_table.Time = drilling_data.time;

fn = fieldnames(features_data);
for i = 1:length(fn)
    features_table.(fn{i}) = features_data.(fn{i});
end

writetable(features_table, fullfile(output_dir, 'diagnostic_features.csv'));

%% 3. Сохранение detected_events.csv
fprintf('    Сохранение detected_events.csv...\n');
if ~isempty(final_events)
    writetable(final_events, fullfile(output_dir, 'detected_events.csv'));
else
    fid = fopen(fullfile(output_dir, 'detected_events.csv'), 'w');
    fprintf(fid, 'start_time,end_time,start_md,event_type,risk_score,confidence_level,severity,explanation\n');
    fprintf(fid, 'Нет обнаруженных событий\n');
    fclose(fid);
end

%% 4. Сохранение drilling_diagnostics_results.mat
fprintf('    Сохранение drilling_diagnostics_results.mat...\n');
results = struct();
results.drilling_data = drilling_data;
results.features_data = features_data;
results.final_events = final_events;
results.timestamp = datetime('now');
results.version = '1.0';

save(fullfile(output_dir, 'drilling_diagnostics_results.mat'), 'results');

%% 5. Сохранение diagnostic_summary.txt
fprintf('    Сохранение diagnostic_summary.txt...\n');
fid = fopen(fullfile(output_dir, 'diagnostic_summary.txt'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s', report_text);
fclose(fid);

%% 6. Сохранение diagnostic_timeseries.png
fprintf('    Сохранение diagnostic_timeseries.png...\n');
if isfield(fig_handles, 'timeseries') && ishandle(fig_handles.timeseries)
    saveas(fig_handles.timeseries, fullfile(output_dir, 'diagnostic_timeseries.png'));
end

%% 7. Сохранение risk_timeline.png
fprintf('    Сохранение risk_timeline.png...\n');
if isfield(fig_handles, 'risk_timeline') && ishandle(fig_handles.risk_timeline)
    saveas(fig_handles.risk_timeline, fullfile(output_dir, 'risk_timeline.png'));
end

%% 8. Сохранение events_for_web.json
fprintf('    Сохранение events_for_web.json...\n');
if ~isempty(final_events)
    json_struct = struct();
    json_struct.timestamp = char(datetime('now'));
    json_struct.total_events = height(final_events);
    
    events_array = [];
    for i = 1:height(final_events)
        evt = struct();
        evt.id = i;
        evt.start_time = char(final_events.start_time(i));
        evt.end_time = char(final_events.end_time(i));
        evt.start_md = final_events.start_md(i);
        evt.event_type = char(final_events.event_type(i));
        evt.risk_score = final_events.risk_score(i);
        evt.confidence_level = char(final_events.confidence_level(i));
        evt.severity = char(final_events.severity(i));
        evt.explanation = char(final_events.explanation(i));
        events_array = [events_array; evt];
    end
    
    json_struct.events = events_array;
    
    json_text = jsonencode(json_struct, 'PrettyPrint', true);
    fid = fopen(fullfile(output_dir, 'events_for_web.json'), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', json_text);
    fclose(fid);
else
    json_struct = struct();
    json_struct.timestamp = char(datetime('now'));
    json_struct.total_events = 0;
    json_struct.events = [];
    
    json_text = jsonencode(json_struct, 'PrettyPrint', true);
    fid = fopen(fullfile(output_dir, 'events_for_web.json'), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', json_text);
    fclose(fid);
end

fprintf('    Все результаты успешно сохранены в директорию %s/\n', output_dir);

%% Вывод списка созданных файлов
fprintf('\n    Созданные файлы:\n');
fprintf('      - raw_drilling_data.csv\n');
fprintf('      - diagnostic_features.csv\n');
fprintf('      - detected_events.csv\n');
fprintf('      - drilling_diagnostics_results.mat\n');
fprintf('      - diagnostic_summary.txt\n');
fprintf('      - diagnostic_timeseries.png\n');
fprintf('      - risk_timeline.png\n');
fprintf('      - events_for_web.json\n');

end
