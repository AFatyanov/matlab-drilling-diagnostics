function drilling_data = generate_synthetic_drilling()
% GENERATE_SYNTHETIC_DRILLING Генерация синтетических данных с физическими корреляциями
%
% Выход:
%   drilling_data - struct с полями:
%       time: datetime array [480x1]
%       data: table [480x15]

%% Параметры симуляции
n_points = 480;
dt_minutes = 15;
start_time = datetime('2026-06-01 00:00:00');
time = start_time + minutes((0:n_points-1)' * dt_minutes);

%% Инициализация
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

%% Базовые параметры
start_md = 2000;
base_wob = 15;
base_rpm = 120;
base_torque = 12;
base_spp = 180;
base_flow = 1800;
base_mw = 1.15;
base_pit = 50;

% Авторегрессионные коэффициенты для плавного шума
noise_memory = 0.7;
noise_wob = 0; noise_rpm = 0; noise_rop = 0; noise_torque = 0;
noise_spp = 0; noise_flow = 0; noise_pit = 0; noise_gas = 0;

%% Генерация параметров
for i = 1:n_points
    t_hours = (i-1) * dt_minutes / 60;
    
    % Литологический фактор (плавные изменения по глубине)
    if i == 1
        MD(i) = start_md;
        TVD(i) = start_md * 0.95;
    else
        MD(i) = MD(i-1);
        TVD(i) = MD(i) * 0.95;
    end
    
    % Литология: плавные переходы между пластами
    lith_factor = 1.0;
    if MD(i) > 2500 && MD(i) < 2700
        lith_factor = 0.6 + 0.4 * (MD(i) - 2500) / 200;  % твёрдая порода
    elseif MD(i) > 3000 && MD(i) < 3200
        lith_factor = 1.3 - 0.3 * (MD(i) - 3000) / 200;  % мягкая порода
    end
    
    % Моделирование операций: бурение и соединения каждые 12 часов
    is_connection = mod(t_hours, 12) < 0.5;
    
    if is_connection
        % Соединение: все параметры на минимуме
        ROP(i) = 0;
        WOB(i) = 0;
        RPM(i) = 0;
        Torque(i) = 2 + rand() * 0.5;  % минимальный момент
        FlowRate(i) = base_flow * 0.3;
        SPP(i) = base_spp * 0.5;
    else
        % Бурение: коррелированные параметры
        
        % WOB с авторегрессионным шумом
        noise_wob = noise_memory * noise_wob + (1-noise_memory) * randn() * 2;
        WOB(i) = base_wob + noise_wob;
        WOB(i) = max(8, min(22, WOB(i)));  % ограничение
        
        % RPM с авторегрессионным шумом
        noise_rpm = noise_memory * noise_rpm + (1-noise_memory) * randn() * 8;
        RPM(i) = base_rpm + noise_rpm;
        RPM(i) = max(80, min(150, RPM(i)));
        
        % ROP: модель drill-off (зависимость от WOB и RPM)
        % ROP = k * WOB^a * RPM^b * lith_factor
        k = 0.015;  % коэффициент
        a = 0.8;    % степень WOB
        b = 0.6;    % степень RPM
        
        noise_rop = noise_memory * noise_rop + (1-noise_memory) * randn() * 3;
        ROP(i) = k * (WOB(i)^a) * (RPM(i)^b) * lith_factor + noise_rop;
        ROP(i) = max(5, min(40, ROP(i)));
        
        % Torque: корреляция с WOB и RPM
        % Torque = c * WOB * (RPM/base_rpm)^d + шум
        c = 0.8;
        d = 0.5;
        noise_torque = noise_memory * noise_torque + (1-noise_memory) * randn() * 1.5;
        Torque(i) = c * WOB(i) * (RPM(i)/base_rpm)^d + noise_torque;
        Torque(i) = max(6, min(20, Torque(i)));
        
        % FlowRate с шумом
        noise_flow = noise_memory * noise_flow + (1-noise_memory) * randn() * 50;
        FlowRate(i) = base_flow + noise_flow;
        FlowRate(i) = max(1500, min(2100, FlowRate(i)));
        
        % SPP: корреляция с FlowRate и глубиной
        % SPP = base_spp * (FlowRate/base_flow)^e * (1 + MD/f)
        e = 1.8;
        f = 10000;
        noise_spp = noise_memory * noise_spp + (1-noise_memory) * randn() * 5;
        SPP(i) = base_spp * (FlowRate(i)/base_flow)^e * (1 + MD(i)/f) + noise_spp;
        
        % Глубина растёт только при бурении
        MD(i) = MD(i) + ROP(i) * (dt_minutes/60);
        TVD(i) = MD(i) * 0.95;
    end
    
    % Hookload: вес колонны минус WOB
    string_weight = 80 + MD(i) * 0.02;
    if is_connection
        Hookload(i) = string_weight * (1.0 + rand() * 0.05);
    else
        Hookload(i) = string_weight - WOB(i) + randn() * 1.5;
    end
    
    % Mud Weight с медленным трендом по глубине
    MudWeight(i) = base_mw + MD(i)/5000 * 0.05 + randn() * 0.008;
    
    % ECD: MW + annular pressure loss
    annular_pressure_equiv = SPP(i) / 200 * 0.05;
    ECD(i) = MudWeight(i) + annular_pressure_equiv;
    
    % Pit Volume: авторегрессионный шум с медленным дрейфом
    if i == 1
        PitVolume(i) = base_pit;
    else
        noise_pit = noise_memory * noise_pit + (1-noise_memory) * randn() * 0.15;
        PitVolume(i) = PitVolume(i-1) + noise_pit;
    end
    
    % Gas: базовый уровень + шум
    noise_gas = noise_memory * noise_gas + (1-noise_memory) * randn() * 0.2;
    Gas(i) = 0.5 + rand() * 0.3 + noise_gas;
    Gas(i) = max(0.1, Gas(i));
    
    % Pore Pressure: градиент по глубине
    PorePressure(i) = 1.05 + MD(i)/8000 * 0.15;
    
    % Fracture Gradient: градиент по глубине
    FractureGradient(i) = 1.65 + MD(i)/6000 * 0.10;
end

%% Формирование выходной структуры
drilling_data = struct();
drilling_data.time = time;
drilling_data.data = table(MD, TVD, ROP, WOB, RPM, Torque, Hookload, ...
                           SPP, FlowRate, MudWeight, ECD, PitVolume, ...
                           Gas, PorePressure, FractureGradient);
drilling_data.complications_ground_truth = table();

fprintf('    Параметры: MD от %.1f до %.1f м\n', min(MD), max(MD));
fprintf('    Средняя ROP: %.1f м/ч\n', mean(ROP(ROP>0)));

end
