function features_data = calculate_diagnostic_features(drilling_data, conn_mask)
% CALCULATE_DIAGNOSTIC_FEATURES Расчёт инженерных и статистических признаков
%
% Вход:
%   drilling_data - struct с данными бурения
%   conn_mask     - логический вектор [Nx1], true = соединение
%
% Выход:
%   features_data - struct с диагностическими признаками

data = drilling_data.data;
n_points = height(data);
is_drilling = ~conn_mask;  % маска нормального бурения

features_data = struct();
features_data.is_drilling = is_drilling;

%% Инженерные признаки давления
% ECD margin относительно PP (overbalance) и FG (underbalance)
features_data.ecd_vs_pp = data.ECD - data.PorePressure;
features_data.fg_vs_ecd = data.FractureGradient - data.ECD;
features_data.mud_window = data.FractureGradient - data.PorePressure;

% Критическое давление: минимум из PP margin и FG margin
features_data.critical_pressure = min(features_data.ecd_vs_pp, features_data.fg_vs_ecd);

%% Статистические признаки - Pit Volume (только по бурению)
window = 20;  % 5 часов
features_data.pit_volume_trend = zeros(n_points, 1);
features_data.pit_volume_rate = zeros(n_points, 1);
features_data.pit_volume_baseline = zeros(n_points, 1);

for i = 1:n_points
    if i <= window
        idx = 1:i;
    else
        idx = (i-window):(i-1);
    end
    
    % Базовая линия только по бурению
    baseline_idx = idx(is_drilling(idx));
    if ~isempty(baseline_idx)
        baseline = mean(data.PitVolume(baseline_idx));
        features_data.pit_volume_baseline(i) = baseline;
        features_data.pit_volume_trend(i) = data.PitVolume(i) - baseline;
    end
    
    if i > 1 && is_drilling(i)
        features_data.pit_volume_rate(i) = data.PitVolume(i) - data.PitVolume(i-1);
    end
end

%% Статистические признаки - Gas (только по бурению)
features_data.gas_rate_change = zeros(n_points, 1);
features_data.gas_zscore = zeros(n_points, 1);

for i = window+1:n_points
    idx = (i-window):(i-1);
    baseline_idx = idx(is_drilling(idx));
    
    if length(baseline_idx) >= 5
        mu = mean(data.Gas(baseline_idx));
        sigma = std(data.Gas(baseline_idx));
        
        if is_drilling(i) && sigma > 0.05
            features_data.gas_zscore(i) = (data.Gas(i) - mu) / sigma;
            features_data.gas_rate_change(i) = data.Gas(i) - data.Gas(i-1);
        end
    end
end

%% Статистические признаки - SPP (Standpipe Pressure)
features_data.spp_deviation = zeros(n_points, 1);
features_data.spp_trend = zeros(n_points, 1);
features_data.spp_baseline = zeros(n_points, 1);

for i = window+1:n_points
    idx = (i-window):(i-1);
    baseline_idx = idx(is_drilling(idx));
    
    if length(baseline_idx) >= 5
        baseline = data.SPP(baseline_idx);
        mu = mean(baseline);
        features_data.spp_baseline(i) = mu;
        features_data.spp_deviation(i) = data.SPP(i) - mu;
        
        % Тренд через линейную регрессию
        if length(baseline) >= 10
            x = (1:length(baseline))';
            p = polyfit(x, baseline, 1);
            features_data.spp_trend(i) = p(1);
        end
    end
end

%% Статистические признаки - Torque
features_data.torque_zscore = zeros(n_points, 1);
features_data.torque_deviation = zeros(n_points, 1);

for i = window+1:n_points
    idx = (i-window):(i-1);
    baseline_idx = idx(is_drilling(idx));
    
    if length(baseline_idx) >= 5 && is_drilling(i)
        mu = mean(data.Torque(baseline_idx));
        sigma = std(data.Torque(baseline_idx));
        
        features_data.torque_deviation(i) = data.Torque(i) - mu;
        if sigma > 0.1
            features_data.torque_zscore(i) = (data.Torque(i) - mu) / sigma;
        end
    end
end

%% Статистические признаки - Hookload
features_data.hookload_zscore = zeros(n_points, 1);
features_data.hookload_deviation = zeros(n_points, 1);

for i = window+1:n_points
    idx = (i-window):(i-1);
    baseline_idx = idx(is_drilling(idx));
    
    if length(baseline_idx) >= 5 && is_drilling(i)
        mu = mean(data.Hookload(baseline_idx));
        sigma = std(data.Hookload(baseline_idx));
        
        features_data.hookload_deviation(i) = data.Hookload(i) - mu;
        if sigma > 0.5
            features_data.hookload_zscore(i) = (data.Hookload(i) - mu) / sigma;
        end
    end
end

%% Статистические признаки - ROP
features_data.rop_trend = zeros(n_points, 1);
features_data.rop_normalized = zeros(n_points, 1);

for i = window+1:n_points
    idx = (i-window):(i-1);
    baseline_idx = idx(is_drilling(idx));
    
    if length(baseline_idx) >= 5 && is_drilling(i)
        rop_baseline = data.ROP(baseline_idx);
        mu = mean(rop_baseline);
        
        features_data.rop_normalized(i) = data.ROP(i) / mu;
        
        % Тренд ROP
        x = (1:length(rop_baseline))';
        p = polyfit(x, rop_baseline, 1);
        features_data.rop_trend(i) = p(1);
    end
end

%% Статистические признаки - Flow Rate
features_data.flow_deviation = zeros(n_points, 1);

for i = window+1:n_points
    idx = (i-window):(i-1);
    baseline_idx = idx(is_drilling(idx));
    
    if length(baseline_idx) >= 5
        mu = mean(data.FlowRate(baseline_idx));
        features_data.flow_deviation(i) = data.FlowRate(i) - mu;
    end
end

%% Композитные признаки
% Индекс нестабильности: комбинация отклонений
features_data.instability_index = abs(features_data.spp_deviation) ./ ...
                                   (features_data.spp_baseline + 1e-6) + ...
                                   abs(features_data.torque_zscore) ./ 5 + ...
                                   abs(features_data.hookload_zscore) ./ 5;

fprintf('    Инженерных признаков: 4\n');
fprintf('    Статистических признаков: 13\n');
fprintf('    Композитных признаков: 1\n');

end
