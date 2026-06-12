%% Создание отсутствующих выходных файлов
fprintf('Загрузка результатов...\n');
load('../output/drilling_diagnostics_results.mat');

fprintf('Построение графиков...\n');
fig_handles = plot_diagnostics(results.drilling_data, results.features_data, results.final_events);

fprintf('Сохранение PNG...\n');
saveas(fig_handles.timeseries, '../output/diagnostic_timeseries.png');
saveas(fig_handles.risk_timeline, '../output/risk_timeline.png');

fprintf('Создание JSON...\n');
if ~isempty(results.final_events)
    json_struct.timestamp = char(datetime('now'));
    json_struct.total_events = height(results.final_events);
    events_array = [];
    for i = 1:height(results.final_events)
        evt.id = i;
        evt.start_time = char(results.final_events.start_time(i));
        evt.end_time = char(results.final_events.end_time(i));
        evt.start_md = results.final_events.start_md(i);
        evt.event_type = char(results.final_events.event_type(i));
        evt.risk_score = results.final_events.risk_score(i);
        evt.confidence_level = char(results.final_events.confidence_level(i));
        evt.severity = char(results.final_events.severity(i));
        evt.explanation = char(results.final_events.explanation(i));
        events_array = [events_array; evt];
    end
    json_struct.events = events_array;
else
    json_struct.timestamp = char(datetime('now'));
    json_struct.total_events = 0;
    json_struct.events = [];
end

json_text = jsonencode(json_struct, 'PrettyPrint', true);
fid = fopen('../output/events_for_web.json', 'w', 'n', 'UTF-8');
fprintf(fid, '%s', json_text);
fclose(fid);

fprintf('Готово! Проверьте output/\n');
