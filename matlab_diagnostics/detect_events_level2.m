function events = detect_events_level2(drilling_data, features_data, conn_mask)
% DETECT_EVENTS_LEVEL2 Обнаружение осложнений - Уровень 2 (инженерные расчёты)
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

%% Правило 1: Kick Detection - ECD близок к Pore Pressure
% Инженерный признак: ECD - PP < 0.05 г/см³ (низкий overbalance)
% + рост газа и pit volume
kick_ecd_margin = 0.05;        % г/см³
kick_gas_threshold = 3.0;      % %
kick_pit_threshold = 1.5;      % м³

for i = 40:n_points
    if ~is_drilling(i), continue; end
    
    ecd_close = features_data.ecd_vs_pp(i) < kick_ecd_margin;
    gas_high = data.Gas(i) > kick_gas_threshold;
    pit_rising = features_data.pit_volume_trend(i) > kick_pit_threshold;
    
    if ecd_close && gas_high && pit_rising
        % Найти начало и конец события
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
% Инженерный признак: FG - ECD < 0.05 г/см³ (низкий underbalance margin)
% + падение pit volume и SPP
loss_fg_margin = 0.05;         % г/см³
loss_pit_threshold = -1.5;     % м³

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

%% Правило 3: Pack-off - рост давления + момента + падение ROP
% Инженерный признак: устойчивый тренд роста SPP + torque
packoff_spp_trend = 0.5;       % бар/точка
packoff_torque_zscore = 1.5;   % z-score
packoff_rop_threshold = 15;    % м/ч

for i = 40:n_points
    if ~is_drilling(i), continue; end
    
    spp_rising = features_data.spp_trend(i) > packoff_spp_trend;
    torque_high = features_data.torque_zscore(i) > packoff_torque_zscore;
    rop_low = data.ROP(i) < packoff_rop_threshold && data.ROP(i) > 0;
    
    if spp_rising && torque_high && rop_low
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.spp_trend(j) < 0.3
                break;
            end
            if features_data.spp_trend(j) > packoff_spp_trend
                start_idx = j;
            end
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.spp_trend(j) < 0.3
                break;
            end
            if features_data.spp_trend(j) > packoff_spp_trend
                end_idx = j;
            end
        end
        
        if end_idx - start_idx >= 4
            severity = min(100, features_data.spp_deviation(i) / 2);
            confidence = min(0.9, 0.7 + severity/200);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'packoff', 'confidence', confidence, ...
                                        'severity', severity);
            break;
        end
    end
end

%% Правило 4: Stuck Pipe - остановка бурения + аномальный hookload
% Инженерный признак: ROP=0 длительно + резкий рост hookload
stuck_hookload_zscore = 2.5;   % z-score
stuck_min_duration = 8;        % минимум 2 часа

for i = 40:n_points
    if ~is_drilling(i), continue; end
    
    % Проверить что ROP=0 длительно
    rop_zero_duration = 0;
    for j = i:min(n_points, i+20)
        if data.ROP(j) < 0.5
            rop_zero_duration = rop_zero_duration + 1;
        else
            break;
        end
    end
    
    if rop_zero_duration >= stuck_min_duration && features_data.hookload_zscore(i) > stuck_hookload_zscore
        start_idx = i;
        end_idx = i + rop_zero_duration - 1;
        
        severity = 85;  % прихват всегда высокая серьёзность
        confidence = min(0.9, 0.8 + features_data.hookload_zscore(i)/10);
        
        event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                    'type', 'stuck', 'confidence', confidence, ...
                                    'severity', severity);
        break;
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
            description_arr{i} = 'Уровень 2: тренд SPP + torque + падение ROP (исключены соединения)';
        else
            description_arr{i} = 'Уровень 2: ROP=0 + аномальный hookload (исключены соединения)';
        end
    end
    
    events = table(start_time_arr, end_time_arr, start_md_arr, event_type_arr, ...
                   confidence_arr, description_arr, ...
                   'VariableNames', {'start_time', 'end_time', 'start_md', ...
                                     'event_type', 'confidence', 'description'});
end

end
