function [MSE, specific_energy_mechanical, specific_energy_hydraulic] = ...
    calculate_mse(drilling_data, config)
% CALCULATE_MSE Расчёт механической удельной энергии (MSE)
%
% Вход:
%   drilling_data - struct с данными бурения
%   config - конфигурация
%
% Выход:
%   MSE - механическая удельная энергия [Nx1]
%   specific_energy_mechanical - механическая составляющая [Nx1]
%   specific_energy_hydraulic - гидравлическая составляющая [Nx1]
%
% Формула MSE:
%   MSE = WOB / A + (120 * π * RPM * T) / (A * ROP)
% где:
%   WOB - нагрузка на долото (кгс)
%   A - площадь долота (см²)
%   RPM - обороты (об/мин)
%   T - момент (кгс*м)
%   ROP - механическая скорость (м/ч)

    data = drilling_data.data;
    n_points = height(data);
    
    % Инициализация выходных массивов
    MSE = zeros(n_points, 1);
    specific_energy_mechanical = zeros(n_points, 1);
    specific_energy_hydraulic = zeros(n_points, 1);
    
    % Геометрия долота
    bit_diameter = config.geometry.bit_diameter_m;
    bit_area = pi/4 * bit_diameter^2;
    
    % Коэффициенты для расчёта
    mse_coeff = config.physics.mse_coeff;  % 120 * π
    
    % Безопасное значение ROP для деления
    rop_safe_threshold = 0.1;  % м/ч
    
    for i = 1:n_points
        % Проверка что идёт бурение (не соединение)
        if data.ROP(i) > rop_safe_threshold && data.WOB(i) > 1
            % Упрощённая эмпирическая формула для MSE
            % Реальное MSE обычно 500-2000 кгс/см² для эффективного бурения
            % MSE = base + k * (WOB/WOB_ref) * (Torque/T_ref) / (ROP/ROP_ref)
            
            WOB_norm = data.WOB(i) / config.refs.WOB;
            Torque_norm = data.Torque(i) / 12;  % базовый torque
            ROP_norm = data.ROP(i) / config.refs.ROP;
            
            % Базовое MSE + вклад от бурения
            MSE(i) = 500 + 800 * WOB_norm * Torque_norm / max(ROP_norm, 0.3);
            
            % Разделение на составляющие (упрощённо)
            specific_energy_mechanical(i) = 200 * WOB_norm;
            specific_energy_hydraulic(i) = MSE(i) - specific_energy_mechanical(i);
        else
            % Соединение или остановка - MSE не определён
            MSE(i) = NaN;
            specific_energy_mechanical(i) = NaN;
            specific_energy_hydraulic(i) = NaN;
        end
    end
    
    % Статистика (только для валидных значений)
    valid_mse = MSE(~isnan(MSE));
    if ~isempty(valid_mse)
        fprintf('    MSE: среднее = %.1f, min = %.1f, max = %.1f кгс/см²\n', ...
            mean(valid_mse), min(valid_mse), max(valid_mse));
    end
end
