function config = get_default_config()
% GET_DEFAULT_CONFIG Возвращает структуру конфигурации по умолчанию
%
% Выход:
%   config - структура с параметрами симуляции и диагностики

    % Симуляция
    config.simulation.n_points = 480;
    config.simulation.dt_minutes = 15;
    config.simulation.start_md = 2000;
    config.simulation.random_seed = 42;
    
    % Геометрия скважины
    config.geometry.bit_diameter_m = 0.2159;      % 8.5"
    config.geometry.hole_diameter_m = 0.2159;     % 8.5"
    config.geometry.pipe_od_m = 0.127;            % 5"
    config.geometry.pipe_id_m = 0.108;            % 4.25"
    
    % Свойства бурового раствора
    config.fluid.mud_weight_base = 1.15;          % г/см³
    config.fluid.pv = 25;                         % cP
    config.fluid.yp = 12;                         % lb/100ft²
    config.fluid.rheology_factor = 1.0;
    
    % Базовые параметры бурения
    config.refs.WOB = 15;                         % тонн
    config.refs.RPM = 120;
    config.refs.FlowRate = 1800;                  % л/мин
    config.refs.ROP = 25;                         % м/ч
    config.refs.HSI = 2.0;                        % HP/in²
    
    % Пороговые значения осложнений
    config.thresholds.kick_margin = 0.03;         % г/см³
    config.thresholds.loss_margin = 0.03;         % г/см³
    config.thresholds.packoff_index = 10.0;       % порог загрузки шлама (увеличен)
    config.thresholds.stuck_index = 1.0;
    config.thresholds.diff_stick_margin = 0.15;   % г/см³
    
    % Детекторы
    config.detectors.window = 20;
    config.detectors.min_event_points = 4;
    
    % Константы для физики
    config.physics.steel_density_equiv = 7.85;    % г/см³
    config.physics.pipe_weight_per_m = 0.025;     % тонн/м
    config.physics.base_bha_weight = 10;          % тонн
    config.physics.k_hyd = 0.08;                  % гидравлический коэффициент
    config.physics.k_cuttings = 0.02;             % коэффициент шлама
    config.physics.rho_scale = 0.098;             % для ECD в г/см³
    config.physics.k_transport = 0.5;             % коэффициент транспорта (уменьшен для реалистичности)
    config.physics.mse_coeff = 120 * pi;          % для MSE
    config.physics.k_influx = 2.5;                % коэффициент притока
    config.physics.k_loss = 3.0;                  % коэффициент поглощения
    
    % Веса для risk score
    config.risk.weights = [0.25, 0.40, 0.20, 0.15];
    config.risk.thresholds = [40, 65, 80];        % low/medium/high/critical
end
