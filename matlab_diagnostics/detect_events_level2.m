function events = detect_events_level2(drilling_data, features_data, conn_mask)
% DETECT_EVENTS_LEVEL2 Обнаружение осложнений - Уровень 2 (инженерные расчёты)
%
% Вход:
%   drilling_data - struct с данными бурения
%   features_data - struct с диагностическими признаками
%   conn_mask - логический вектор [Nx1], true = соединение
%
% Выход:
%   events - table с обнаруженными событиями

data = drilling_data.data;
time = drilling_data.time;
n_points = height(data);
is_drilling = ~conn_mask;

events = table();
event_list = {};

%% Правило 1: Kick Detection - ECD близок к Pore Pressure
kick_ecd_margin = 0.05;
kick_gas_threshold = 3.0;
kick_pit_threshold = 1.5;

for i = 40:n_points
    if ~is_drilling(i), continue; end
    
    ecd_close = features_data.ecd_vs_pp(i) < kick_ecd_margin;
    gas_high = data.Gas(i) > kick_gas_threshold;
    pit_rising = features_data.pit_volume_trend(i) > kick_pit_threshold;
    
    if ecd_close && gas_high && pit_rising
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.ecd_vs_pp(j) > 0.1
                break;
            end
            if features_data.ecd_vs_pp(j) < kick_ecd_margin
                start_idx = j;
            end
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.ecd_vs_pp(j) > 0.1
                break;
            end
            if features_data.ecd_vs_pp(j) < kick_ecd_margin
                end_idx = j;
            end
        end
        
        if end_idx - start_idx >= 4
            underbalance = -features_data.ecd_vs_pp(i);
            severity = min(100, underbalance * 500);
            confidence = min(0.9, 0.7 + severity/200);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'kick', 'confidence', confidence, ...
                                        'severity', severity);
            break;
        end
    end
end

%% Правило 2: Mud Losses - ECD близок к Fracture Gradient
loss_fg_margin = 0.05;
loss_pit_threshold = -1.5;

for i = 40:n_points
    if ~is_drilling(i), continue; end
    
    fg_close = features_data.fg_vs_ecd(i) < loss_fg_margin;
    pit_falling = features_data.pit_volume_trend(i) < loss_pit_threshold;
    
    if fg_close && pit_falling
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.fg_vs_ecd(j) > 0.1
                break;
            end
            if features_data.fg_vs_ecd(j) < loss_fg_margin
                start_idx = j;
            end
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.fg_vs_ecd(j) > 0.1
                break;
            end
            if features_data.fg_vs_ecd(j) < loss_fg_margin
                end_idx = j;
            end
        end
        
        if end_idx - start_idx >= 4
            overbalance = -features_data.fg_vs_ecd(i);
            severity = min(100, overbalance * 400);
            confidence = min(0.9, 0.7 + severity/200);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'losses', 'confidence', confidence, ...
                                        'severity', severity);
            break;
        end
    end
end

%% Правило 3: Pack-off - packoff_index + тренды
packoff_index_threshold = 1.0;
packoff_spp_trend = 0.5;
packoff_torque_zscore = 1.5;
packoff_rop_threshold = 15;

for i = 40:n_points
    if ~is_drilling(i), continue; end
    
    packoff_high = features_data.packoff_index(i) > packoff_index_threshold;
    spp_rising = features_data.spp_trend(i) > packoff_spp_trend;
    torque_high = features_data.torque_zscore(i) > packoff_torque_zscore;
    rop_low = data.ROP(i) < packoff_rop_threshold && data.ROP(i) > 0;
    
    if packoff_high && spp_rising && torque_high && rop_low
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.packoff_index(j) < 0.7
                break;
            end
            if features_data.packoff_index(j) > packoff_index_threshold
                start_idx = j;
            end
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.packoff_index(j) < 0.7
                break;
            end
            if features_data.packoff_index(j) > packoff_index_threshold
                end_idx = j;
            end
        end
        
        if end_idx - start_idx >= 4
            severity = min(100, features_data.packoff_index(i) * 50);
            confidence = min(0.9, 0.7 + severity/200);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'packoff', 'confidence', confidence, ...
                                        'severity', severity);
            break;
        end
    end
end

%% Правило 4: Stuck Pipe - stuck_risk_index
stuck_index_threshold = 1.0;
stuck_min_duration = 8;

for i = 40:n_points
    if ~is_drilling(i), continue; end
    
    % Проверяем stuck_risk_index
    if features_data.stuck_risk_index(i) > stuck_index_threshold
        % Проверяем что ROP=0 длительно
        rop_zero_duration = 0;
        for j = i:min(n_points, i+20)
            if data.ROP(j) < 0.5
                rop_zero_duration = rop_zero_duration + 1;
            else
                break;
            end
        end
        
        if rop_zero_duration >= stuck_min_duration
            start_idx = i;
            end_idx = i + rop_zero_duration - 1;
            
            severity = 85;
            confidence = min(0.9, 0.8 + features_data.stuck_risk_index(i)/10);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'stuck', 'confidence', confidence, ...
                                        'severity', severity);
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
        
        if strcmp(evt.type, 'kick')
            description_arr{i} = 'Уровень 2: ECD близко к PP + рост газа/pit (исключены соединения)';
        elseif strcmp(evt.type, 'losses')
            description_arr{i} = 'Уровень 2: ECD близко к FG + падение pit (исключены соединения)';
        elseif strcmp(evt.type, 'packoff')
            description_arr{i} = 'Уровень 2: packoff_index + тренды SPP/Torque/ROP (исключены соединения)';
        else
            description_arr{i} = 'Уровень 2: stuck_risk_index + ROP=0 (исключены соединения)';
        end
    end
    
    events = table(start_time_arr, end_time_arr, start_md_arr, event_type_arr, ...
                   confidence_arr, description_arr, ...
                   'VariableNames', {'start_time', 'end_time', 'start_md', ...
                                     'event_type', 'confidence', 'description'});
end

end
