function final_events = aggregate_detections(events_L1, events_L2, events_L3, complications)
% AGGREGATE_DETECTIONS Объединение результатов трёх уровней детекции
%
% Вход:
%   events_L1, events_L2, events_L3 - таблицы событий от детекторов
%   complications - таблица физических осложнений (от trigger_complications)
%
% Выход:
%   final_events - таблица с агрегированными событиями

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
        
        % Взвешенная модель риска
        weights = [0.25, 0.40, 0.20, 0.15];  % L1, L2, L3, severity
        
        % Определяем уровень каждого детектора
        l1_conf = 0; l2_conf = 0; l3_conf = 0;
        l1_count = 0; l2_count = 0; l3_count = 0;
        
        for k = 1:length(overlapping)
            idx_k = overlapping(k);
            % Определяем уровень по описанию
            desc = type_events.description{idx_k};
            if contains(desc, 'Уровень 1')
                l1_conf = l1_conf + type_events.confidence(idx_k);
                l1_count = l1_count + 1;
            elseif contains(desc, 'Уровень 2')
                l2_conf = l2_conf + type_events.confidence(idx_k);
                l2_count = l2_count + 1;
            elseif contains(desc, 'Уровень 3')
                l3_conf = l3_conf + type_events.confidence(idx_k);
                l3_count = l3_count + 1;
            end
        end
        
        % Средние значения по уровням
        if l1_count > 0, l1_conf = l1_conf / l1_count; end
        if l2_count > 0, l2_conf = l2_conf / l2_count; end
        if l3_count > 0, l3_conf = l3_conf / l3_count; end
        
        % Физическая тяжесть (severity)
        phys_severity = 0.5;  % по умолчанию средняя
        if ~isempty(complications)
            % Ищем соответствующее физическое осложнение
            for c = 1:height(complications)
                comp = complications(c, :);
                if contains(comp.type{1}, merged_type) && ...
                   comp.start_time{1} >= merged_start && ...
                   comp.start_time{1} <= merged_end
                    phys_severity = comp.severity / 100;
                    break;
                end
            end
        end
        
        % Расчёт risk score
        risk_score = 100 * (weights(1) * l1_conf + ...
                           weights(2) * l2_conf + ...
                           weights(3) * l3_conf + ...
                           weights(4) * phys_severity);
        
        % Конфиденс
        merged_confidence = mean(type_events.confidence(overlapping));
        
        % Уровень уверенности
        if merged_confidence >= 0.75
            conf_level = 'высокий';
        elseif merged_confidence >= 0.60
            conf_level = 'средний';
        else
            conf_level = 'низкий';
        end
        
        % Серьёзность
        if risk_score >= 80
            severity = 'critical';
        elseif risk_score >= 60
            severity = 'severe';
        elseif risk_score >= 40
            severity = 'moderate';
        else
            severity = 'minor';
        end
        
        % Объяснение с физическими деталями
        explanation = sprintf('Обнаружено %d детектор(ов). Тип: %s. Confidence: %.0f%%. Risk score: %.0f/100. ', ...
                              length(overlapping), merged_type, merged_confidence*100, risk_score);
        
        if strcmp(merged_type, 'kick')
            explanation = [explanation 'Физика: ECD < PorePressure, приток пластового флюида, рост Pit Volume и Gas.'];
        elseif strcmp(merged_type, 'losses')
            explanation = [explanation 'Физика: ECD > FractureGradient, поглощение раствора в пласт, падение Pit Volume.'];
        elseif strcmp(merged_type, 'packoff')
            explanation = [explanation 'Физика: высокая загрузка шлама (packoff_index), рост SPP и Torque, падение ROP.'];
        elseif strcmp(merged_type, 'stuck')
            explanation = [explanation 'Физика: прихват колонны (механический или дифференциальный), ROP=0, аномалии Hookload и Torque.'];
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
