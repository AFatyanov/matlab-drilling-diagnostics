function [ECD, annular_velocity, pressure_loss_annulus, cuttings_pressure_loss] = ...
    calculate_hydraulics(drilling_data, cuttings_load, config)
% CALCULATE_HYDRAULICS Расчёт гидравлических параметров и ECD
%
% Вход:
%   drilling_data - struct с данными бурения
%   cuttings_load - массив загрузки шламом [Nx1]
%   config - конфигурация
%
% Выход:
%   ECD - эквивалентная плотность циркуляции [Nx1]
%   annular_velocity - скорость в кольцевом пространстве [Nx1]
%   pressure_loss_annulus - потери давления в кольце [Nx1]
%   cuttings_pressure_loss - потери от шлама [Nx1]

    data = drilling_data.data;
    n_points = height(data);
    
    % Инициализация выходных массивов
    ECD = zeros(n_points, 1);
    annular_velocity = zeros(n_points, 1);
    pressure_loss_annulus = zeros(n_points, 1);
    cuttings_pressure_loss = zeros(n_points, 1);
    
    % Геометрия кольцевого пространства
    hole_diameter = config.geometry.hole_diameter_m;
    pipe_od = config.geometry.pipe_od_m;
    annular_area = pi/4 * (hole_diameter^2 - pipe_od^2);
    
    % Константы для расчёта ECD
    rho_scale = config.physics.rho_scale;  % перевод в г/см³
    
    for i = 1:n_points
        % Конвертация расхода из л/мин в м³/с
        flow_m3s = data.FlowRate(i) / 1000 / 60;
        
        % Скорость в кольцевом пространстве (м/с)
        annular_velocity(i) = flow_m3s / annular_area;
        
        % Потери давления в кольце (упрощённая эмпирическая модель)
        % ΔP = k * Q^n * L / A^m, где Q - расход, L - длина (TVD), A - площадь
        % Используем степенной закон для турбулентного/ламинарного потока
        TVD = data.TVD(i);
        
        % Базовые потери давления от циркуляции
        if data.FlowRate(i) > 100  % только когда есть циркуляция
            % Упрощённая эмпирическая модель: ΔP ~ Q^1.8 * L
            % Коэффициент подобран для реалистичных значений 10-30 бар на 2000 м
            pressure_loss_annulus(i) = 5.0 * flow_m3s^1.8 * TVD;
        end
        
        % Дополнительные потери от концентрации шлама
        % Реально cuttings pressure loss обычно 1-5 бар
        if cuttings_load(i) > 0
            cuttings_pressure_loss(i) = 0.001 * cuttings_load(i) * TVD;
        end
        
        % Расчёт ECD
        % ECD = MW + (ΔP_annulus + ΔP_cuttings) / (ρ_scale * TVD)
        % где ρ_scale переводит давление в эквивалентную плотность
        if TVD > 0 && data.FlowRate(i) > 100
            total_pressure_loss = pressure_loss_annulus(i) + cuttings_pressure_loss(i);
            ECD(i) = data.MudWeight(i) + total_pressure_loss / (rho_scale * TVD);
        else
            ECD(i) = data.MudWeight(i);  % статическая плотность
        end
    end
    
    fprintf('    Гидравлика: средняя AV = %.2f м/с, ECD = %.3f г/см³\n', ...
        mean(annular_velocity), mean(ECD));
end
