function events = detect_events_level3(drilling_data, features_data, conn_mask)
% DETECT_EVENTS_LEVEL3 Обнаружение осложнений - Уровень 3 (статистические методы)
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

%% Правило 1: Kick Detection - статистические аномалии
kick_pit_threshold = 1.0;
kick_gas_zscore = 2.0;
kick_spp_threshold = 10;
kick_ecd_threshold = 0.05;

for i = 50:n_points
    if ~is_drilling(i), continue; end
    
    pit_anomaly = features_data.pit_volume_trend(i) > kick_pit_threshold;
    gas_anomaly = features_data.gas_zscore(i) > kick_gas_zscore;
    spp_anomaly = features_data.spp_deviation(i) > kick_spp_threshold;
    ecd_anomaly = features_data.ecd_vs_pp(i) < kick_ecd_threshold;
    
    % Голосование: минимум 3 из 4 аномалий
    votes = sum([pit_anomaly, gas_anomaly, spp_anomaly, ecd_anomaly]);
    
    if votes >= 3
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
            anomaly_strength = votes / 4 + features_data.gas_zscore(i) / 5 + ...
                              features_data.pit_volume_trend(i) / 5;
            confidence = min(0.85, 0.5 + anomaly_strength / 10);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'kick', 'confidence', confidence);
            break;
        end
    end
end

%% Правило 2: Losses Detection - статистические аномалии
loss_pit_rate = -0.3;
loss_spp_threshold = -15;
loss_fg_threshold = 0.05;
sustained_points = 5;

for i = 50:n_points
    if ~is_drilling(i), continue; end
    
    pit_drop = features_data.pit_volume_rate(i) < loss_pit_rate;
    spp_drop = features_data.spp_deviation(i) < loss_spp_threshold;
    fg_anomaly = features_data.fg_vs_ecd(i) < loss_fg_threshold;
    
    % Проверить устойчивое падение
    sustained = true;
    for j = max(1,i-sustained_points+1):i
        if ~is_drilling(j) || features_data.pit_volume_rate(j) >= 0
            sustained = false;
            break;
        end
    end
    
    % Голосование: минимум 2 из 3 + sustained
    votes = sum([pit_drop, spp_drop, fg_anomaly]);
    
    if votes >= 2 && sustained
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
            anomaly_strength = votes / 3 + abs(features_data.pit_volume_rate(i)) / 2 + ...
                              abs(features_data.spp_deviation(i)) / 50;
            confidence = min(0.85, 0.5 + anomaly_strength / 10);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'losses', 'confidence', confidence);
            break;
        end
    end
end

%% Правило 3: Pack-off Detection - статистические аномалии
packoff_index_threshold = 0.8;
packoff_spp_trend = 0.3;
packoff_torque_zscore = 1.5;
packoff_rop_declining = -0.5;
packoff_mse_rising = 0.2;

for i = 50:n_points
    if ~is_drilling(i), continue; end
    
    packoff_high = features_data.packoff_index(i) > packoff_index_threshold;
    spp_trend_positive = features_data.spp_trend(i) > packoff_spp_trend;
    torque_high = features_data.torque_zscore(i) > packoff_torque_zscore;
    rop_declining = features_data.rop_trend(i) < packoff_rop_declining;
    
    % Проверка MSE (если доступно)
    mse_rising = false;
    if ~isnan(features_data.MSE(i)) && i > 10
        mse_baseline = mean(features_data.MSE(i-10:i-1));
        if ~isnan(mse_baseline) && mse_baseline > 0
            mse_rising = features_data.MSE(i) > mse_baseline * (1 + packoff_mse_rising);
        end
    end
    
    % Голосование: минимум 3 из 5 аномалий
    votes = sum([packoff_high, spp_trend_positive, torque_high, rop_declining, mse_rising]);
    
    if votes >= 3
        start_idx = i;
        for j = i-1:-1:max(1,i-30)
            if ~is_drilling(j) || features_data.packoff_index(j) < 0.5
                break;
            end
            start_idx = j;
        end
        
        end_idx = i;
        for j = i+1:min(n_points,i+30)
            if ~is_drilling(j) || features_data.packoff_index(j) < 0.5
                break;
            end
            end_idx = j;
        end
        
        if end_idx - start_idx >= 4
            anomaly_strength = votes / 5 + features_data.packoff_index(i) / 3 + ...
                              features_data.torque_zscore(i) / 5;
            confidence = min(0.85, 0.5 + anomaly_strength / 10);
            
            event_list{end+1} = struct('start_idx', start_idx, 'end_idx', end_idx, ...
                                        'type', 'packoff', 'confidence', confidence);
            break;
        end
    end
end

%% Правило 4: Stuck Pipe Detection - статистические аномалии
stuck_hookload_zscore = 2.0;
stuck_torque_zscore = 2.0;
stuck_rop_threshold = 0.5;
stuck_index_threshold = 1.0;

for i = 50:n_points
    if ~is_drilling(i), continue; end
    
    hookload_spike = features_data.hookload_zscore(i) > stuck_hookload_zscore;
    torque_spike = features_data.torque_zscore(i) > stuck_torque_zscore;
    rop_zero = data.ROP(i) < stuck_rop_threshold;
    stuck_high = features_data.stuck_risk_index(i) > stuck_index_threshold;
    
    % Голосование: минимум 3 из 4 аномалий
    votes = sum([hookload_spike, torque_spike, rop_zero, stuck_high]);
    
    if votes >= 3
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
            anomaly_strength = votes / 4 + features_data.stuck_risk_index(i) / 5;
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
        description_arr{i} = 'Уровень 3: статистические аномалии (Z-score, тренды, MSE, исключены соединения)';
    end
    
    events = table(start_time_arr, end_time_arr, start_md_arr, event_type_arr, ...
                   confidence_arr, description_arr, ...
                   'VariableNames', {'start_time', 'end_time', 'start_md', ...
                                     'event_type', 'confidence', 'description'});
end

end
