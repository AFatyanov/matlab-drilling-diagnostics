function drilling_data = apply_sensor_response(drilling_data, complications, ...
    ECD, cuttings_load, packoff_index, MSE, conn_mask, config)
% APPLY_SENSOR_RESPONSE Применение отклика датчиков на сработавшие осложнения
%
% Вход:
%   drilling_data - struct с данными бурения
%   complications - таблица с осложнениями
%   ECD, cuttings_load, packoff_index, MSE - физические параметры
%   conn_mask - маска соединений
%   config - конфигурация
%
% Выход:
%   drilling_data - обновлённые данные с реалистичным откликом датчиков
%
% Логика отклика:
%   Kick: PitVolume растёт, Gas растёт, SPP аномалия, MW падает
%   Losses: PitVolume падает, SPP падает, FlowRate аномалия
%   Pack-off: SPP растёт, Torque растёт, ROP падает, FlowRate падает
%   Stuck: ROP = 0, Hookload аномалия, Torque аномалия

    data = drilling_data.data;
    n_points = height(data);
    dt_hours = config.simulation.dt_minutes / 60;
    
    % Коэффициенты отклика
    k_influx = config.physics.k_influx;
    k_loss = config.physics.k_loss;
    
    for c = 1:height(complications)
        comp = complications(c, :);
        
        % Находим индексы временного диапазона осложнения
        start_idx = find(drilling_data.time >= comp.start_time{1}, 1, 'first');
        end_idx = find(drilling_data.time <= comp.end_time{1}, 1, 'last');
        
        if isempty(start_idx) || isempty(end_idx)
            continue;
        end
        
        % Применяем отклик только к точкам бурения (не соединениям)
        for i = start_idx:min(end_idx, n_points)
            if conn_mask(i)
                continue;
            end
            
            % Прогресс осложнения (0-1)
            progress = (i - start_idx) / max(1, end_idx - start_idx);
            progress = min(1, progress * 1.5);  % ускоренное развитие
            
            switch comp.type{1}
                case 'kick'
                    % Приток: рост PitVolume и Gas
                    kick_drawdown = data.PorePressure(i) - ECD(i);
                    if kick_drawdown > 0
                        influx_rate = k_influx * kick_drawdown^1.5 * dt_hours;
                        data.PitVolume(i) = data.PitVolume(i) + influx_rate * progress;
                        data.Gas(i) = data.Gas(i) + influx_rate * 2 * progress;
                        
                        % Падение плотности раствора
                        data.MudWeight(i) = data.MudWeight(i) - influx_rate * 0.01 * progress;
                        
                        % Аномалия давления
                        data.SPP(i) = data.SPP(i) + influx_rate * 5 * progress;
                    end
                    
                case 'losses'
                    % Поглощение: падение PitVolume и SPP
                    loss_overpressure = ECD(i) - data.FractureGradient(i);
                    if loss_overpressure > 0
                        loss_rate = k_loss * loss_overpressure^1.3 * dt_hours;
                        data.PitVolume(i) = max(0, data.PitVolume(i) - loss_rate * progress);
                        data.SPP(i) = data.SPP(i) - loss_rate * 8 * progress;
                        data.FlowRate(i) = data.FlowRate(i) - loss_rate * 50 * progress;
                        
                        % Корректировка ECD
                        ECD(i) = ECD(i) - loss_rate * 0.02 * progress;
                    end
                    
                case 'packoff'
                    % Прихват шламом: рост SPP, Torque, падение ROP и FlowRate
                    packoff_severity = packoff_index(i) * progress;
                    
                    data.SPP(i) = data.SPP(i) + packoff_severity * 40;
                    data.Torque(i) = data.Torque(i) * (1 + packoff_severity * 0.5);
                    data.ROP(i) = data.ROP(i) * max(0.1, 1 - packoff_severity * 0.7);
                    data.FlowRate(i) = data.FlowRate(i) * max(0.6, 1 - packoff_severity * 0.3);
                    
                    % Рост MSE
                    if ~isnan(MSE(i))
                        MSE(i) = MSE(i) * (1 + packoff_severity * 0.8);
                    end
                    
                case {'stuck_mechanical', 'stuck_differential'}
                    % Прихват: ROP = 0, аномалии Hookload и Torque
                    
                    if strcmp(comp.type{1}, 'stuck_mechanical')
                        % Механический прихват
                        if progress > 0.2
                            data.ROP(i) = 0;
                            data.Torque(i) = data.Torque(i) * (1 + progress * 1.5);
                            data.Hookload(i) = data.Hookload(i) + progress * 15;
                            data.SPP(i) = data.SPP(i) + progress * 20;
                        end
                    else
                        % Дифференциальный прихват
                        data.ROP(i) = 0;
                        overbalance = ECD(i) - data.PorePressure(i);
                        stick_force = overbalance * 10 * progress;
                        data.Hookload(i) = data.Hookload(i) + stick_force;
                        data.Torque(i) = data.Torque(i) * (1 + progress * 0.8);
                    end
            end
        end
    end
    
    % Обновляем drilling_data
    drilling_data.data = data;
    
    fprintf('    Применён отклик датчиков для %d осложнений\n', height(complications));
end
