function drilling_data = generate_synthetic_drilling()
% GENERATE_SYNTHETIC_DRILLING Генерация синтетических данных с физическими корреляциями
%
% Выход:
%   drilling_data - struct с полями:
%       time: datetime array [480x1]
%       data: table [480x15]
%       formations: table - геологические пласты

    % Загрузка конфигурации и модели пластов
    config = get_default_config();
    formations = generate_formation_model();
    
    % Параметры симуляции
    n_points = config.simulation.n_points;
    dt_minutes = config.simulation.dt_minutes;
    start_time = datetime('2026-06-01 00:00:00');
    time = start_time + minutes((0:n_points-1)' * dt_minutes);
    dt_hours = dt_minutes / 60;
    
    % Инициализация массивов
    MD = zeros(n_points, 1);
    TVD = zeros(n_points, 1);
    ROP = zeros(n_points, 1);
    WOB = zeros(n_points, 1);
    RPM = zeros(n_points, 1);
    Torque = zeros(n_points, 1);
    Hookload = zeros(n_points, 1);
    SPP = zeros(n_points, 1);
    FlowRate = zeros(n_points, 1);
    MudWeight = zeros(n_points, 1);
    ECD = zeros(n_points, 1);
    PitVolume = zeros(n_points, 1);
    Gas = zeros(n_points, 1);
    PorePressure = zeros(n_points, 1);
    FractureGradient = zeros(n_points, 1);
    
    % Авторегрессионные коэффициенты для плавного шума
    noise_memory = 0.7;
    noise_wob = 0; noise_rpm = 0; noise_torque = 0;
    noise_spp = 0; noise_flow = 0; noise_pit = 0; noise_gas = 0;
    
    % Геометрия
    hole_area = pi/4 * config.geometry.hole_diameter_m^2;
    bit_area = pi/4 * config.geometry.bit_diameter_m^2;
    
    % Начальная глубина
    MD(1) = config.simulation.start_md;
    TVD(1) = MD(1) * 0.95;
    
    % Генерация параметров по точкам
    for i = 1:n_points
        t_hours = (i-1) * dt_minutes / 60;
        
        % Найти активный пласт
        active_form = find_formation(formations, MD(i));
        
        % Градиенты давления из пласта
        PorePressure(i) = active_form.PPGradient;
        FractureGradient(i) = active_form.FGGradient;
        
        % Литологический фактор
        lith_factor = active_form.Drillability;
        
        % Моделирование операций: бурение и соединения каждые 12 часов
        is_connection = mod(t_hours, 12) < 0.5;
        
        if is_connection
            % Соединение: все параметры на минимуме
            ROP(i) = 0;
            WOB(i) = 0;
            RPM(i) = 0;
            Torque(i) = 2 + rand() * 0.5;
            FlowRate(i) = config.refs.FlowRate * 0.3;
            SPP(i) = 180 * 0.5;
            
            % Глубина не растёт при соединении
            if i > 1
                MD(i) = MD(i-1);
                TVD(i) = TVD(i-1);
            end
        else
            % Бурение: коррелированные параметры
            
            % WOB с авторегрессионным шумом
            noise_wob = noise_memory * noise_wob + (1-noise_memory) * randn() * 2;
            WOB(i) = config.refs.WOB + noise_wob;
            WOB(i) = max(8, min(22, WOB(i)));
            
            % RPM с авторегрессионным шумом
            noise_rpm = noise_memory * noise_rpm + (1-noise_memory) * randn() * 8;
            RPM(i) = config.refs.RPM + noise_rpm;
            RPM(i) = max(80, min(150, RPM(i)));
            
            % ROP: formation-aware модель
            wob_term = (WOB(i) / config.refs.WOB)^0.8;
            rpm_term = (RPM(i) / config.refs.RPM)^0.6;
            formation_term = lith_factor;
            hydraulic_term = 1.0;  % будет уточнено в calculate_hydraulics
            dp_term = 1.0;         % будет уточнено после расчёта ECD
            wear_term = 1.0;       % упрощённо
            
            ROP(i) = config.refs.ROP * wob_term * rpm_term * formation_term * ...
                     hydraulic_term * dp_term * wear_term;
            ROP(i) = max(5, min(40, ROP(i)));
            
            % Глубина растёт только при бурении
            if i > 1
                MD(i) = MD(i-1) + ROP(i) * dt_hours;
                TVD(i) = MD(i) * 0.95;
            end
            
            % Torque: функция WOB, RPM, абразивности
            base_torque = 12;
            torque = base_torque * ...
                     (WOB(i) / config.refs.WOB)^0.9 * ...
                     (RPM(i) / config.refs.RPM)^0.4 * ...
                     (1 + active_form.Abrasiveness * 0.2);
            noise_torque = noise_memory * noise_torque + (1-noise_memory) * randn() * 1.5;
            Torque(i) = max(6, min(20, torque + noise_torque));
            
            % FlowRate с шумом
            noise_flow = noise_memory * noise_flow + (1-noise_memory) * randn() * 50;
            FlowRate(i) = config.refs.FlowRate + noise_flow;
            FlowRate(i) = max(1500, min(2100, FlowRate(i)));
            
            % SPP: функция FlowRate и глубины
            spp_base = 180;
            SPP(i) = spp_base * (FlowRate(i)/config.refs.FlowRate)^1.8 * ...
                     (1 + MD(i)/10000);
            noise_spp = noise_memory * noise_spp + (1-noise_memory) * randn() * 5;
            SPP(i) = SPP(i) + noise_spp;
        end
        
        % Hookload: вес колонны минус WOB
        string_weight = config.physics.base_bha_weight + MD(i) * config.physics.pipe_weight_per_m;
        buoyancy = 1 - MudWeight(max(1,i-1)) / config.physics.steel_density_equiv;
        if is_connection
            Hookload(i) = string_weight * buoyancy * (1.0 + rand() * 0.05);
        else
            Hookload(i) = string_weight * buoyancy - WOB(i) + randn() * 1.5;
        end
        
        % Mud Weight с медленным трендом по глубине
        MudWeight(i) = config.fluid.mud_weight_base + MD(i)/5000 * 0.05 + randn() * 0.008;
        
        % ECD: упрощённый расчёт (будет уточнён в calculate_hydraulics)
        annular_pressure_equiv = SPP(i) / 200 * 0.05;
        ECD(i) = MudWeight(i) + annular_pressure_equiv;
        
        % Pit Volume: авторегрессионный шум
        if i == 1
            PitVolume(i) = 50;
        else
            noise_pit = noise_memory * noise_pit + (1-noise_memory) * randn() * 0.15;
            PitVolume(i) = PitVolume(i-1) + noise_pit;
        end
        
        % Gas: базовый уровень + газовый потенциал пласта
        noise_gas = noise_memory * noise_gas + (1-noise_memory) * randn() * 0.2;
        Gas(i) = 0.5 + active_form.GasPotential * 0.5 + rand() * 0.3 + noise_gas;
        Gas(i) = max(0.1, Gas(i));
    end
    
    % Формирование выходной структуры
    drilling_data = struct();
    drilling_data.time = time;
    drilling_data.data = table(MD, TVD, ROP, WOB, RPM, Torque, Hookload, ...
                               SPP, FlowRate, MudWeight, ECD, PitVolume, ...
                               Gas, PorePressure, FractureGradient);
    drilling_data.formations = formations;
    drilling_data.complications_ground_truth = table();
    
    fprintf('    Параметры: MD от %.1f до %.1f м\n', min(MD), max(MD));
    fprintf('    Средняя ROP: %.1f м/ч\n', mean(ROP(ROP>0)));
end

function form = find_formation(formations, md)
% Найти активный пласт для данной глубины
    idx = find(md >= formations.TopMD & md < formations.BottomMD, 1);
    if isempty(idx)
        idx = height(formations);  % последний пласт если глубже
    end
    form = formations(idx, :);
end
