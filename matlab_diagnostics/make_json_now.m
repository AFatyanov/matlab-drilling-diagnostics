%% Создание events_for_web.json
load('../output/drilling_diagnostics_results.mat');
fe = results.final_events;
if ~isempty(fe)
    js.timestamp = char(datetime('now'));
    js.total_events = height(fe);
    ea = [];
    for i = 1:height(fe)
        e.id = i;
        e.start_time = char(fe.start_time(i));
        e.end_time = char(fe.end_time(i));
        e.start_md = fe.start_md(i);
        e.event_type = char(fe.event_type(i));
        e.risk_score = fe.risk_score(i);
        e.confidence_level = char(fe.confidence_level(i));
        e.severity = char(fe.severity(i));
        e.explanation = char(fe.explanation(i));
        ea = [ea; e];
    end
    js.events = ea;
else
    js.timestamp = char(datetime('now'));
    js.total_events = 0;
    js.events = [];
end
jt = jsonencode(js, 'PrettyPrint', true);
fid = fopen('../output/events_for_web.json', 'w', 'n', 'UTF-8');
fprintf(fid, '%s', jt);
fclose(fid);
fprintf('events_for_web.json создан\n');
