function drilling_data = inject_complications(drilling_data, conn_mask)
% INJECT_COMPLICATIONS Моделирование осложнений с нелинейным развитием
%
% Вход:
%   drilling_data - struct с базовыми данными бурения
%   conn_mask     - логический вектор [Nx1], true = соединение
%
% Выход:
%   drilling_data - обогащённый struct с complications_ground_truth

time = drilling_data.time;
data = drilling_data.data;
n_points = height(data);
is_drilling = ~conn_mask;

%% Определение интервалов для осложнений
% Kick: точки 150-180 (газонефтеводопроявление)
kick_start = 150;
kick_end = 180;

% Mud Losses: точки 250-270 (поглощение)
loss_start = 250;
loss_end = 270;

% Pack-off: точки 330-360 (затяжки)
packoff_start = 330;
packoff_end = 360;

% Stuck Pipe: точки 420-450 (прихват)
stuck_start = 420;
stuck_end = 450;

%% Моделирование Kick - нелинейное развитие
% Фаза 1: начальное проявление (медленный рост)
% Фаза 2: активное развитие (экспоненциальный рост)
% Фаза 3: стабилизация (плато)
fprintf('    Моделирование Kick: точки %d-%d\n', kick_start, kick_end);
kick_duration = kick_end - kick_start;

for i = kick_start:kick_end
    if ~is_drilling(i), continue; end
    
    progress = (i - kick_start) / kick_duration;
    
    % Нелинейная интенсивность: медленное начало, быстрое развитие, плато
    if progress < 0.3
        intensity = progress^2 * 3;  % медленный старт
    elseif progress < 0.7
        intensity = 0.3 + (progress - 0.3) * 2;  % активная фаза
    else
        intensity = 1.0 - (progress - 0.7)^2 * 0.5;  % стабилизация
    end
    
    % Рост pit volume (приток пластового флюида)
    data.PitVolume(i) = data.PitVolume(i) + intensity * 3.5;
    
    % Рост газопоказаний (коррелирует с pit volume)
    gas_increase = intensity * 9.0 + intensity^2 * 2.0;
    data.Gas(i) = data.Gas(i) + gas_increase;
    
    % Рост SPP (повышение давления из-за притока)
    data.SPP(i) = data.SPP(i) + intensity * 18;
    
    % Снижение плотности раствора (разбавление газом)
    if i > kick_start + 5
        mw_decrease = intensity * 0.04 + intensity^2 * 0.01;
        data.MudWeight(i) = data.MudWeight(i) - mw_decrease;
    end
    
    % ECD пересчёт с учётом изменений
    annular_pressure_equiv = data.SPP(i) / 200 * 0.05;
    data.ECD(i) = data.MudWeight(i) + annular_pressure_equiv;
end

%% Моделирование Mud Losses - нелинейное поглощение
% Фаза 1: начальное поглощение (медленное)
% Фаза 2: усиление поглощения
% Фаза 3: частичное восстановление (закупорка трещин)
fprintf('    Моделирование Mud Losses: точки %d-%d\n', loss_start, loss_end);
loss_duration = loss_end - loss_start;

for i = loss_start:loss_end
    if ~is_drilling(i), continue; end
    
    progress = (i - loss_start) / loss_duration;
    
    % Нелинейная интенсивность: быстрое развитие, затем замедление
    if progress < 0.5
        intensity = progress * 1.5;  % быстрое развитие
    else
        intensity = 0.75 + (progress - 0.5) * 0.5;  % замедление
    end
    
    % Падение pit volume (уход раствора в пласт)
    data.PitVolume(i) = data.PitVolume(i) - intensity * 4.5;
    
    % Падение SPP (снижение гидравлического сопротивления)
    data.SPP(i) = data.SPP(i) - intensity * 28;
    
    % Рост ROP (бурение становится легче при поглощении)
    if data.ROP(i) > 0
        rop_increase = 1 + intensity * 0.4 + intensity^2 * 0.1;
        data.ROP(i) = data.ROP(i) * rop_increase;
    end
    
    % ECD снижается
    annular_pressure_equiv = data.SPP(i) / 200 * 0.05;
    data.ECD(i) = data.MudWeight(i) + annular_pressure_equiv;
end

%% Моделирование Pack-off - постепенное ухудшение
% Фаза 1: начальные признаки (медленное ухудшение)
% Фаза 2: прогрессирование
% Фаза 3: критическое состояние
fprintf('    Моделирование Pack-off: точки %d-%d\n', packoff_start, packoff_end);
packoff_duration = packoff_end - packoff_start;

for i = packoff_start:packoff_end
    if ~is_drilling(i), continue; end
    
    progress = (i - packoff_start) / packoff_duration;
    
    % Нелинейная интенсивность: ускорение к концу
    intensity = progress^1.5;
    
    % Рост SPP (затруднение циркуляции)
    spp_increase = intensity * 45 + intensity^2 * 10;
    data.SPP(i) = data.SPP(i) + spp_increase;
    
    % Рост момента (затруднение вращения)
    torque_multiplier = 1 + intensity * 0.6 + intensity^2 * 0.2;
    data.Torque(i) = data.Torque(i) * torque_multiplier;
    
    % Снижение ROP (затруднение бурения)
    if data.ROP(i) > 0
        rop_multiplier = max(0.2, 1 - intensity * 0.7);
        data.ROP(i) = data.ROP(i) * rop_multiplier;
    end
    
    % Снижение расхода (затруднение циркуляции)
    flow_multiplier = 1 - intensity * 0.25;
    data.FlowRate(i) = data.FlowRate(i) * flow_multiplier;
end

%% Моделирование Stuck Pipe - резкий прихват
% Фаза 1: предвестники (небольшое ухудшение)
% Фаза 2: прихват (резкая остановка)
% Фаза 3: попытки расхаживания (высокие нагрузки)
fprintf('    Моделирование Stuck Pipe: точки %d-%d\n', stuck_start, stuck_end);
stuck_duration = stuck_end - stuck_start;

for i = stuck_start:stuck_end
    if ~is_drilling(i), continue; end
    
    progress = (i - stuck_start) / stuck_duration;
    
    if progress < 0.15
        % Фаза 1: предвестники
        data.ROP(i) = data.ROP(i) * (1 - progress * 4);
        data.Torque(i) = data.Torque(i) * (1 + progress * 3);
    else
        % Фаза 2-3: прихват и попытки расхаживания
        data.ROP(i) = 0;  % бурение остановлено
        
        % Высокий момент при попытках вращения
        torque_multiplier = 1.9 + 0.3 * sin(progress * 10);  % колебания
        data.Torque(i) = data.Torque(i) * torque_multiplier;
        
        % Резкий рост hookload при попытках расхаживания
        hookload_increase = 25 + 15 * rand() + 10 * sin(progress * 8);
        data.Hookload(i) = data.Hookload(i) + hookload_increase;
    end
end

%% Обновление данных
drilling_data.data = data;

%% Создание ground truth таблицы осложнений
complications = table();
complications.start_idx = [kick_start; loss_start; packoff_start; stuck_start];
complications.end_idx = [kick_end; loss_end; packoff_end; stuck_end];
complications.start_time = time([kick_start; loss_start; packoff_start; stuck_start]);
complications.end_time = time([kick_end; loss_end; packoff_end; stuck_end]);
complications.type = {'kick'; 'losses'; 'packoff'; 'stuck'};
complications.start_md = data.MD([kick_start; loss_start; packoff_start; stuck_start]);

drilling_data.complications_ground_truth = complications;

end
