function events = detect_events_level1(drilling_data, features_data, conn_mask)
% DETECT_EVENTS_LEVEL1 Обнаружение осложнений - Уровень 1 (калиброванные эвристики)
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

%% Правило 1: Kick Detection (газонефтеводопроявление)
% Признаки: рост pit volume (>2 м³), рост газа (>3%), рост SPP (>10 бар)
% Только при бурении (не на соединениях)
kick_threshold_pit = 2.0;      % м³
kick_threshold_gas = 3.0;      % %
kick_threshold_spp = 10;       % бар
min_duration = 4;              % минимум 1 час (4 точки)

for i = 30:n_points
    if ~is_drilling(i), continue; end
    
    pit_ok = features_data.pit_volume_trend(i) > kick_threshold_pit;
    gas_ok = data.Gas(i) > kick_threshold_gas;
    spp_ok = features_data.spp_deviation(i) > kick_threshold_spp;
    
    if pit_ok && gas_ok && spp_ok
        % Найти начало события (обратно до потери признака)
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.pit_volume_trend(j) < 1.0
                break;
            end
            if features_data.pit_volume_trend(j) > kick_threshold_pit
                start_idx = j;
            end
        end
        
        % Найти конец (вперёд до потери признака)
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.pit_volume_trend(j) < 1.0
                break;
            end
            if features_data.pit_volume_trend(j) > kick_threshold_pit
                end_idx = j;
            end
        end
        
        % Проверить минимальную длительность
        if end_idx - start_idx >= min_duration
            confidence = min(0.9, 0.6 + features_data.pit_volume_trend(i)/10);
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'kick', 'confidence', confidence);
            break;  % одно событие kick
        end
    end
end

%% Правило 2: Mud Losses (поглощение бурового раствора)
% Признаки: падение pit volume (<-2 м³), падение SPP (<-15 бар)
loss_threshold_pit = -2.0;     % м³
loss_threshold_spp = -15;      % бар

for i = 30:n_points
    if ~is_drilling(i), continue; end
    
    pit_ok = features_data.pit_volume_trend(i) < loss_threshold_pit;
    spp_ok = features_data.spp_deviation(i) < loss_threshold_spp;
    
    if pit_ok && spp_ok
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.pit_volume_trend(j) > -1.0
                break;
            end
            if features_data.pit_volume_trend(j) < loss_threshold_pit
                start_idx = j;
            end
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.pit_volume_trend(j) > -1.0
                break;
            end
            if features_data.pit_volume_trend(j) < loss_threshold_pit
                end_idx = j;
            end
        end
        
        if end_idx - start_idx >= min_duration
            confidence = min(0.9, 0.6 + abs(features_data.pit_volume_trend(i))/10);
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'losses', 'confidence', confidence);
            break;
        end
    end
end

%% Правило 3: Pack-off (затяжки/посадки)
% Признаки: рост SPP (>25 бар), рост torque (z-score > 2.0), падение ROP
packoff_threshold_spp = 25;    % бар
packoff_threshold_torque = 2.0; % z-score
packoff_threshold_rop = 10;    % м/ч

for i = 30:n_points
    if ~is_drilling(i), continue; end
    
    spp_ok = features_data.spp_deviation(i) > packoff_threshold_spp;
    torque_ok = features_data.torque_zscore(i) > packoff_threshold_torque;
    rop_ok = data.ROP(i) < packoff_threshold_rop && data.ROP(i) > 0;
    
    if spp_ok && torque_ok && rop_ok
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.spp_deviation(j) < 15
                break;
            end
            if features_data.spp_deviation(j) > packoff_threshold_spp
                start_idx = j;
            end
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.spp_deviation(j) < 15
                break;
            end
            if features_data.spp_deviation(j) > packoff_threshold_spp
                end_idx = j;
            end
        end
        
        if end_idx - start_idx >= min_duration
            confidence = min(0.9, 0.6 + features_data.torque_zscore(i)/10);
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'packoff', 'confidence', confidence);
            break;
        end
    end
end

%% Правило 4: Stuck Pipe (прихват колонны)
% Признаки: ROP=0 (длительно, >1 час), резкий рост hookload (z-score > 3.0)
stuck_threshold_hookload = 3.0; % z-score
stuck_min_duration = 8;         % минимум 2 часа (8 точек)

for i = 30:n_points
    if ~is_drilling(i), continue; end
    
    % Проверить что ROP=0 длительно
    rop_zero_duration = 0;
    for j = i:min(n_points, i+20)
        if data.ROP(j) < 0.1
            rop_zero_duration = rop_zero_duration + 1;
        else
            break;
        end
    end
    
    if rop_zero_duration >= stuck_min_duration && features_data.hookload_zscore(i) > stuck_threshold_hookload
        start_idx = i;
        end_idx = i + rop_zero_duration - 1;
        
        confidence = min(0.9, 0.7 + features_data.hookload_zscore(i)/10);
        event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                    'type', 'stuck', 'confidence', confidence);
        break;
    end
end

%% Формирование таблицы событий
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
        description_arr{i} = sprintf('Уровень 1: калиброванные пороговые правила (исключены соединения)');
    end
    
    events = table(start_time_arr, end_time_arr, start_md_arr, event_type_arr, ...
                   confidence_arr, description_arr, ...
                   'VariableNames', {'start_time', 'end_time', 'start_md', ...
                                     'event_type', 'confidence', 'description'});
end

end
