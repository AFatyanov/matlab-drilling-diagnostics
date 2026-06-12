function [cuttings_load, cleaning_efficiency, packoff_index] = ...
    calculate_hole_cleaning(drilling_data, annular_velocity, config)
% CALCULATE_HOLE_CLEANING Расчёт очистки ствола скважины и загрузки шламом
%
% Вход:
%   drilling_data - struct с данными бурения
%   annular_velocity - скорость в кольцевом пространстве [Nx1]
%   config - конфигурация
%
% Выход:
%   cuttings_load - загрузка шлама [Nx1], относительная единица
%   cleaning_efficiency - эффективность очистки [Nx1], 0-1
%   packoff_index - индекс риска прихвата [Nx1]
%
% Модель:
%   cuttings_generation = ROP * hole_area * dt
%   transport_capacity = k_transport * annular_velocity * cleaning_efficiency * dt
%   cuttings_load(t) = max(0, cuttings_load(t-1) + generation - transport)
%   packoff_index = cuttings_load / threshold

    data = drilling_data.data;
    n_points = height(data);
    dt_hours = config.simulation.dt_minutes / 60;
    
    % Инициализация выходных массивов
    cuttings_load = zeros(n_points, 1);
    cleaning_efficiency = zeros(n_points, 1);
    packoff_index = zeros(n_points, 1);
    
    % Геометрия
    hole_diameter = config.geometry.hole_diameter_m;
    hole_area = pi/4 * hole_diameter^2;
    
    % Базовые параметры для нормализации
    FlowRef = config.refs.FlowRate;
    RPMRef = config.refs.RPM;
    AV_ref = 0.8;  % эталонная кольцевая скорость, м/с
    
    % Порог загрузки шлама для расчёта packoff_index
    cuttings_threshold = config.thresholds.packoff_index;
    
    % Коэффициенты
    k_transport = config.physics.k_transport;
    
    for i = 1:n_points
        % Эффективность очистки зависит от расхода, оборотов и угла наклона
        % Упрощённо: считаем вертикальную скважину (наклон = 0)
        inclination_factor = 0.0;  % для вертикальной скважины
        
        % Очистка лучше при высоком расходе и оборотах
        if data.FlowRate(i) > 100 && data.RPM(i) > 10
            cleaning_efficiency(i) = min(1.0, ...
                0.4 + 0.3 * (data.FlowRate(i) / FlowRef) + ...
                0.2 * (data.RPM(i) / RPMRef) - ...
                0.1 * inclination_factor);
        else
            cleaning_efficiency(i) = 0.2;  % низкая очистка при соединении
        end
        
        % Генерация шлама (только при бурении)
        if data.ROP(i) > 0.1
            cuttings_generation = data.ROP(i) * hole_area * dt_hours;
        else
            cuttings_generation = 0;
        end
        
        % Транспортная способность
        transport_capacity = k_transport * annular_velocity(i) * ...
                            cleaning_efficiency(i) * dt_hours;
        
        % Обновление загрузки шлама
        if i > 1
            cuttings_load(i) = max(0, ...
                cuttings_load(i-1) + cuttings_generation - transport_capacity);
        else
            cuttings_load(i) = max(0, cuttings_generation - transport_capacity);
        end
        
        % Индекс риска прихвата
        packoff_index(i) = cuttings_load(i) / cuttings_threshold;
    end
    
    % Статистика
    fprintf('    Очистка: средняя загрузка шлама = %.3f, packoff_index = %.3f\n', ...
        mean(cuttings_load), mean(packoff_index));
end
