function final_events = aggregate_detections(events_L1, events_L2, events_L3)
% AGGREGATE_DETECTIONS Объединение результатов трёх уровней детекции

%% Объединение всех событий
all_events = [events_L1; events_L2; events_L3];

if isempty(all_events)
    final_events = table();
    return;
end

%% Группировка по типу и времени
unique_types = unique(all_events.event_type);
merged_list = {};

for t = 1:length(unique_types)
    type_mask = strcmp(all_events.event_type, unique_types{t});
    type_events = all_events(type_mask, :);
    
    if isempty(type_events)
        continue;
    end
    
    [~, idx] = sort(type_events.start_time);
    type_events = type_events(idx, :);
    
    i = 1;
    while i <= height(type_events)
        current = type_events(i, :);
        
        overlapping = [];
        for j = i:height(type_events)
            if type_events.start_time(j) <= current.end_time
                overlapping = [overlapping; j];
            else
                break;
            end
        end
        
        merged_start = min(type_events.start_time(overlapping));
        merged_end = max(type_events.end_time(overlapping));
        merged_md = type_events.start_md(overlapping(1));
        merged_type = unique_types{t};
        
        confidences = type_events.confidence(overlapping);
        merged_confidence = mean(confidences);
        
        risk_score = merged_confidence * 100;
        
        if merged_confidence >= 0.75
            conf_level = 'высокий';
        elseif merged_confidence >= 0.60
            conf_level = 'средний';
        else
            conf_level = 'низкий';
        end
        
        if risk_score >= 80
            severity = 'critical';
        elseif risk_score >= 60
            severity = 'severe';
        elseif risk_score >= 40
            severity = 'moderate';
        else
            severity = 'minor';
        end
        
        explanation = sprintf('Обнаружено %d детектор(ов). Тип: %s. Confidence: %.0f%%. ', ...
                              length(overlapping), merged_type, merged_confidence*100);
        
        if strcmp(merged_type, 'kick')
            explanation = [explanation 'Признаки: рост pit volume, газопоказаний, давления.'];
        elseif strcmp(merged_type, 'losses')
            explanation = [explanation 'Признаки: падение pit volume, давления в манифольде.'];
        elseif strcmp(merged_type, 'packoff')
            explanation = [explanation 'Признаки: рост давления, момента, падение ROP.'];
        elseif strcmp(merged_type, 'stuck')
            explanation = [explanation 'Признаки: остановка бурения, рост hookload и torque.'];
        end
        
        merged_list{end+1} = struct('start_time', merged_start, ...
                                     'end_time', merged_end, ...
                                     'start_md', merged_md, ...
                                     'event_type', merged_type, ...
                                     'risk_score', risk_score, ...
                                     'confidence_level', conf_level, ...
                                     'severity', severity, ...
                                     'explanation', explanation);
        
        i = overlapping(end) + 1;
    end
end

%% Формирование финальной таблицы
if ~isempty(merged_list)
    n_events = length(merged_list);
    start_time_arr = NaT(n_events, 1);
    end_time_arr = NaT(n_events, 1);
    start_md_arr = zeros(n_events, 1);
    event_type_arr = cell(n_events, 1);
    risk_score_arr = zeros(n_events, 1);
    confidence_level_arr = cell(n_events, 1);
    severity_arr = cell(n_events, 1);
    explanation_arr = cell(n_events, 1);
    
    for i = 1:n_events
        evt = merged_list{i};
        start_time_arr(i) = evt.start_time;
        end_time_arr(i) = evt.end_time;
        start_md_arr(i) = evt.start_md;
        event_type_arr{i} = evt.event_type;
        risk_score_arr(i) = evt.risk_score;
        confidence_level_arr{i} = evt.confidence_level;
        severity_arr{i} = evt.severity;
        explanation_arr{i} = evt.explanation;
    end
    
    final_events = table(start_time_arr, end_time_arr, start_md_arr, event_type_arr, ...
                         risk_score_arr, confidence_level_arr, severity_arr, explanation_arr, ...
                         'VariableNames', {'start_time', 'end_time', 'start_md', 'event_type', ...
                                           'risk_score', 'confidence_level', 'severity', 'explanation'});
else
    final_events = table();
end

end
