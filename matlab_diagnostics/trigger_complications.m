function complications = trigger_complications(drilling_data, ECD, cuttings_load, ...
    packoff_index, MSE, conn_mask, config)
% TRIGGER_COMPLICATIONS Запуск осложнений на основе физических условий
%
% Вход:
%   drilling_data - struct с данными бурения
%   ECD - эквивалентная плотность циркуляции [Nx1]
%   cuttings_load - загрузка шлама [Nx1]
%   packoff_index - индекс риска прихвата [Nx1]
%   MSE - механическая удельная энергия [Nx1]
%   conn_mask - маска соединений [Nx1]
%   config - конфигурация
%
% Выход:
%   complications - таблица с сработавшими осложнениями
%
% Логика триггеров:
%   Kick: ECD < PorePressure - kick_margin (продолжительное время)
%   Losses: ECD > FractureGradient - loss_margin (продолжительное время)
%   Pack-off: packoff_index > threshold + SPP trend + Torque trend
%   Stuck (mechanical): packoff_index > 1.2 + Torque high + ROP falling
%   Stuck (differential): ECD - PorePressure > diff_stick_margin + stationary + permeable

    data = drilling_data.data;
    n_points = height(data);
    dt_hours = config.simulation.dt_minutes / 60;
    
    % Пороги
    kick_margin = config.thresholds.kick_margin;
    loss_margin = config.thresholds.loss_margin;
    packoff_threshold = config.thresholds.packoff_index;
    diff_stick_margin = config.thresholds.diff_stick_margin;
    min_duration = config.detectors.min_event_points;
    
    % Инициализация таблицы осложнений
    complications = table();
    complications.start_time = datetime.empty(0,1);
    complications.end_time = datetime.empty(0,1);
    complications.start_md = double.empty(0,1);
    complications.type = cell.empty(0,1);
    complications.mechanism = cell.empty(0,1);
    complications.severity = double.empty(0,1);
    
    % Временные окна для проверки продолжительности
    window = 8;  % 2 часа (8 точек по 15 мин)
    
    for i = window:n_points
        % Пропускаем соединения
        if conn_mask(i)
            continue;
        end
        
        % === KICK: ECD < PorePressure - margin ===
        kick_drawdown = data.PorePressure(i) - ECD(i);
        if kick_drawdown > kick_margin
            % Проверяем продолжительность
            kick_count = 0;
            for j = i-window+1:i
                if ~conn_mask(j) && (data.PorePressure(j) - ECD(j)) > kick_margin
                    kick_count = kick_count + 1;
                end
            end
            
            if kick_count >= min_duration
                % Проверяем что это новое событие (не продолжение предыдущего)
                is_new = true;
                if height(complications) > 0
                    last_kick = complications(end, :);
                    if strcmp(last_kick.type{1}, 'kick') && ...
                       (drilling_data.time(i) - last_kick.end_time{1}) < minutes(30)
                        is_new = false;
                    end
                end
                
                if is_new
                    severity = min(100, kick_drawdown * 500);
                    complications = [complications; ...
                        table(drilling_data.time(i), drilling_data.time(i+5), ...
                              data.MD(i), 'kick', 'influx', severity, ...
                              'VariableNames', complications.Properties.VariableNames)];
                end
            end
        end
        
        % === LOSSES: ECD > FractureGradient + margin ===
        loss_overpressure = ECD(i) - data.FractureGradient(i);
        if loss_overpressure > loss_margin
            % Проверяем продолжительность
            loss_count = 0;
            for j = i-window+1:i
                if ~conn_mask(j) && (ECD(j) - data.FractureGradient(j)) > loss_margin
                    loss_count = loss_count + 1;
                end
            end
            
            if loss_count >= min_duration
                is_new = true;
                if height(complications) > 0
                    last_loss = complications(end, :);
                    if strcmp(last_loss.type{1}, 'losses') && ...
                       (drilling_data.time(i) - last_loss.end_time{1}) < minutes(30)
                        is_new = false;
                    end
                end
                
                if is_new
                    severity = min(100, loss_overpressure * 400);
                    complications = [complications; ...
                        table(drilling_data.time(i), drilling_data.time(i+5), ...
                              data.MD(i), 'losses', 'fracture', severity, ...
                              'VariableNames', complications.Properties.VariableNames)];
                end
            end
        end
        
        % === PACK-OFF: packoff_index > threshold + trends ===
        if packoff_index(i) > packoff_threshold
            % Проверяем тренды SPP и Torque
            spp_trend = mean(data.SPP(i-4:i)) - mean(data.SPP(i-8:i-5));
            torque_trend = mean(data.Torque(i-4:i)) - mean(data.Torque(i-8:i-5));
            rop_trend = mean(data.ROP(i-4:i)) - mean(data.ROP(i-8:i-5));
            
            if spp_trend > 5 && torque_trend > 0.5 && rop_trend < -2
                is_new = true;
                if height(complications) > 0
                    last_packoff = complications(end, :);
                    if strcmp(last_packoff.type{1}, 'packoff') && ...
                       (drilling_data.time(i) - last_packoff.end_time{1}) < minutes(30)
                        is_new = false;
                    end
                end
                
                if is_new
                    severity = min(100, packoff_index(i) * 50);
                    complications = [complications; ...
                        table(drilling_data.time(i), drilling_data.time(i+8), ...
                              data.MD(i), 'packoff', 'cuttings_bed', severity, ...
                              'VariableNames', complications.Properties.VariableNames)];
                end
            end
        end
        
        % === STUCK (mechanical): packoff_index > 1.2 + Torque high + ROP falling ===
        if packoff_index(i) > 1.2 && data.Torque(i) > 18 && data.ROP(i) < 5
            % Проверяем продолжительность ROP падения
            rop_low_count = 0;
            for j = i-window+1:i
                if data.ROP(j) < 5
                    rop_low_count = rop_low_count + 1;
                end
            end
            
            if rop_low_count >= min_duration
                is_new = true;
                if height(complications) > 0
                    last_stuck = complications(end, :);
                    if (strcmp(last_stuck.type{1}, 'stuck_mechanical') || ...
                        strcmp(last_stuck.type{1}, 'stuck_differential')) && ...
                       (drilling_data.time(i) - last_stuck.end_time{1}) < minutes(30)
                        is_new = false;
                    end
                end
                
                if is_new
                    severity = 85;
                    complications = [complications; ...
                        table(drilling_data.time(i), drilling_data.time(i+10), ...
                              data.MD(i), 'stuck_mechanical', 'mechanical', severity, ...
                              'VariableNames', complications.Properties.VariableNames)];
                end
            end
        end
        
        % === STUCK (differential): high overbalance + stationary + permeable ===
        overbalance = ECD(i) - data.PorePressure(i);
        stationary = data.ROP(i) < 0.5 && data.RPM(i) < 5;
        % Упрощённо: считаем проницаемость высокой если Gas > 1.5
        permeable = data.Gas(i) > 1.5;
        
        if overbalance > diff_stick_margin && stationary && permeable
            % Проверяем продолжительность стоянки
            stationary_count = 0;
            for j = i-window+1:i
                if data.ROP(j) < 0.5 && data.RPM(j) < 5
                    stationary_count = stationary_count + 1;
                end
            end
            
            if stationary_count >= min_duration
                is_new = true;
                if height(complications) > 0
                    last_stuck = complications(end, :);
                    if (strcmp(last_stuck.type{1}, 'stuck_mechanical') || ...
                        strcmp(last_stuck.type{1}, 'stuck_differential')) && ...
                       (drilling_data.time(i) - last_stuck.end_time{1}) < minutes(30)
                        is_new = false;
                    end
                end
                
                if is_new
                    severity = 90;
                    complications = [complications; ...
                        table(drilling_data.time(i), drilling_data.time(i+8), ...
                              data.MD(i), 'stuck_differential', 'differential', severity, ...
                              'VariableNames', complications.Properties.VariableNames)];
                end
            end
        end
    end
    
    fprintf('    Сработало осложнений: %d\n', height(complications));
end
