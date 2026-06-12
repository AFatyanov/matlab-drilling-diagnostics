function events = detect_events_level3(drilling_data, features_data, conn_mask)
% DETECT_EVENTS_LEVEL3 Обнаружение осложнений - Уровень 3 (статистические методы)
%
% Вход:
%   drilling_data - struct с данными бурения
%   features_data - struct с диагностическими признаками
%   conn_mask     - логический вектор [Nx1], true = соединение
%
% Выход:
%   events - table с обнаруженными событиями

data = drilling_data.data;
time = drilling_data.time;
n_points = height(data);
is_drilling = ~conn_mask;

events = table();
event_list = {};

%% Правило 1: Kick Detection - статистические аномалии
% Комбинация: pit volume trend + gas z-score + spp deviation
kick_pit_threshold = 1.0;      % м³
kick_gas_zscore = 2.0;         % z-score
kick_spp_threshold = 10;       % бар

for i = 50:n_points
    if ~is_drilling(i), continue; end
    
    pit_anomaly = features_data.pit_volume_trend(i) > kick_pit_threshold;
    gas_anomaly = features_data.gas_zscore(i) > kick_gas_zscore;
    spp_anomaly = features_data.spp_deviation(i) > kick_spp_threshold;
    
    if pit_anomaly && gas_anomaly && spp_anomaly
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j)
                break;
            end
            if features_data.pit_volume_trend(j) > kick_pit_threshold
                start_idx = j;
            end
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j)
                break;
            end
            if features_data.pit_volume_trend(j) > kick_pit_threshold
                end_idx = j;
            end
        end
        
        if end_idx - start_idx >= 4
            % Уверенность на основе силы аномалий
            anomaly_strength = features_data.gas_zscore(i) / 5 + ...
                              features_data.pit_volume_trend(i) / 5 + ...
                              features_data.spp_deviation(i) / 50;
            confidence = min(0.85, 0.5 + anomaly_strength / 10);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'kick', 'confidence', confidence);
            break;
        end
    end
end

%% Правило 2: Losses Detection - статистические аномалии
% Комбинация: pit volume rate + spp deviation + sustained trend
loss_pit_rate = -0.3;          % м³/точка
loss_spp_threshold = -15;      % бар
sustained_points = 5;          % устойчивый тренд

for i = 50:n_points
    if ~is_drilling(i), continue; end
    
    pit_drop = features_data.pit_volume_rate(i) < loss_pit_rate;
    spp_drop = features_data.spp_deviation(i) < loss_spp_threshold;
    
    % Проверить устойчивое падение
    sustained = true;
    for j = max(1,i-sustained_points+1):i
        if ~is_drilling(j) || features_data.pit_volume_rate(j) >= 0
            sustained = false;
            break;
        end
    end
    
    if pit_drop && spp_drop && sustained
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.pit_volume_rate(j) >= 0
                break;
            end
            start_idx = j;
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.pit_volume_rate(j) >= 0
                break;
            end
            end_idx = j;
        end
        
        if end_idx - start_idx >= 4
            anomaly_strength = abs(features_data.pit_volume_rate(i)) / 2 + ...
                              abs(features_data.spp_deviation(i)) / 50;
            confidence = min(0.85, 0.5 + anomaly_strength / 10);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'losses', 'confidence', confidence);
            break;
        end
    end
end

%% Правило 3: Pack-off Detection - тренды и Z-scores
% Комбинация: SPP trend + torque z-score + ROP declining
packoff_spp_trend = 0.3;       % бар/точка
packoff_torque_zscore = 1.5;   % z-score
packoff_rop_declining = -0.5;  % м/ч/точка

for i = 50:n_points
    if ~is_drilling(i), continue; end
    
    spp_trend_positive = features_data.spp_trend(i) > packoff_spp_trend;
    torque_high = features_data.torque_zscore(i) > packoff_torque_zscore;
    rop_declining = features_data.rop_trend(i) < packoff_rop_declining;
    
    if spp_trend_positive && torque_high && rop_declining
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.spp_trend(j) < 0.2
                break;
            end
            start_idx = j;
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.spp_trend(j) < 0.2
                break;
            end
            end_idx = j;
        end
        
        if end_idx - start_idx >= 4
            anomaly_strength = features_data.spp_trend(i) / 2 + ...
                              features_data.torque_zscore(i) / 5 + ...
                              abs(features_data.rop_trend(i)) / 2;
            confidence = min(0.85, 0.5 + anomaly_strength / 10);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'packoff', 'confidence', confidence);
            break;
        end
    end
end

%% Правило 4: Stuck Pipe Detection - аномалии hookload и torque
% Комбинация: hookload spike + torque spike + ROP zero
stuck_hookload_zscore = 2.0;  % z-score
stuck_torque_zscore = 2.0;     % z-score
stuck_rop_threshold = 0.5;     % м/ч

for i = 50:n_points
    if ~is_drilling(i), continue; end
    
    hookload_spike = features_data.hookload_zscore(i) > stuck_hookload_zscore;
    torque_spike = features_data.torque_zscore(i) > stuck_torque_zscore;
    rop_zero = data.ROP(i) < stuck_rop_threshold;
    
    if hookload_spike && torque_spike && rop_zero
        start_idx = i;
        
        % Найти длительность ROP=0
        end_idx = i;
        for j = i+1:min(n_points, i+30)
            if data.ROP(j) < stuck_rop_threshold
                end_idx = j;
            else
                break;
            end
        end
        
        if end_idx - start_idx >= 8
            anomaly_strength = features_data.hookload_zscore(i) / 5 + ...
                              features_data.torque_zscore(i) / 5;
            confidence = min(0.85, 0.6 + anomaly_strength / 10);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'stuck', 'confidence', confidence);
            break;
        end
    end
end

%% Формирование таблицы
if ~isempty(event_list)
    n_events = length(event_list);
    start_time_arr = NaT(n_events, 1);
    end_time_arr = NaT(n_events, 1);
    start_md_arr = zeros(n_events, 1);
    event_type_arr = cell(n_events, 1);
    confidence_arr = zeros(n_events, 1);
    description_arr = cell(n_events, 1);
    
    for i = 1:n_events
        evt = event_list{i};
        start_time_arr(i) = time(evt.start_idx);
        end_time_arr(i) = time(evt.end_idx);
        start_md_arr(i) = data.MD(evt.start_idx);
        event_type_arr{i} = evt.type;
        confidence_arr(i) = evt.confidence;
        description_arr{i} = 'Уровень 3: статистические аномалии (Z-score, тренды, исключены соединения)';
    end
    
    events = table(start_time_arr, end_time_arr, start_md_arr, event_type_arr, ...
                   confidence_arr, description_arr, ...
                   'VariableNames', {'start_time', 'end_time', 'start_md', ...
                                     'event_type', 'confidence', 'description'});
end

end
