function fig_handles = plot_diagnostics(drilling_data, features_data, final_events, ...
    conn_mask, ECD, cuttings_load, packoff_index, MSE)
% PLOT_DIAGNOSTICS Построение диагностических графиков
%
% Вход:
%   drilling_data - struct с данными бурения
%   features_data - struct с признаками
%   final_events - table с событиями
%   conn_mask - маска соединений
%   ECD, cuttings_load, packoff_index, MSE - физические параметры
%
% Выход:
%   fig_handles - struct с handles графиков

data = drilling_data.data;
time = drilling_data.time;

fig_handles = struct();

%% График 1: Diagnostic Timeseries (основной)
fig1 = figure('Position', [100, 100, 1400, 1200], 'Visible', 'off');

% Подграфик 1: MD и ROP
subplot(6,1,1);
yyaxis left
plot(time, data.MD, 'b-', 'LineWidth', 1.5);
ylabel('MD (м)', 'FontSize', 10);
yyaxis right
plot(time, data.ROP, 'r-', 'LineWidth', 1);
ylabel('ROP (м/ч)', 'FontSize', 10);
title('Глубина и механическая скорость проходки', 'FontSize', 12);
grid on;

% Подграфик 2: Pit Volume и Gas
subplot(6,1,2);
yyaxis left
plot(time, data.PitVolume, 'b-', 'LineWidth', 1.5);
ylabel('Pit Volume (м³)', 'FontSize', 10);
yyaxis right
plot(time, data.Gas, 'r-', 'LineWidth', 1);
ylabel('Gas (%)', 'FontSize', 10);
title('Объём амбаров и газопоказания', 'FontSize', 12);
grid on;

% Подграфик 3: SPP и Torque
subplot(6,1,3);
yyaxis left
plot(time, data.SPP, 'b-', 'LineWidth', 1.5);
ylabel('SPP (бар)', 'FontSize', 10);
yyaxis right
plot(time, data.Torque, 'r-', 'LineWidth', 1);
ylabel('Torque (кН·м)', 'FontSize', 10);
title('Давление в манифольде и крутящий момент', 'FontSize', 12);
grid on;

% Подграфик 4: WOB и Hookload
subplot(6,1,4);
yyaxis left
plot(time, data.WOB, 'b-', 'LineWidth', 1.5);
ylabel('WOB (тонн)', 'FontSize', 10);
yyaxis right
plot(time, data.Hookload, 'r-', 'LineWidth', 1);
ylabel('Hookload (тонн)', 'FontSize', 10);
title('Нагрузка на долото и на крюк', 'FontSize', 12);
grid on;

% Подграфик 5: ECD vs PP и FG
subplot(6,1,5);
plot(time, ECD, 'b-', 'LineWidth', 2, 'DisplayName', 'ECD');
hold on;
plot(time, data.PorePressure, 'g--', 'LineWidth', 1.5, 'DisplayName', 'Pore Pressure');
plot(time, data.FractureGradient, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Fracture Gradient');

if ~isempty(final_events)
    ylim_vals = ylim;
    for i = 1:height(final_events)
        evt = final_events(i,:);
        patch([evt.start_time evt.end_time evt.end_time evt.start_time], ...
              [ylim_vals(1) ylim_vals(1) ylim_vals(2) ylim_vals(2)], ...
              'red', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    end
end

ylabel('Плотность (г/см³ экв)', 'FontSize', 10);
xlabel('Время', 'FontSize', 10);
title('ECD, поровое давление и градиент гидроразрыва', 'FontSize', 12);
legend('Location', 'best');
grid on;
hold off;

% Подграфик 6: Cuttings Load и Pack-off Index
subplot(6,1,6);
yyaxis left
plot(time, cuttings_load, 'b-', 'LineWidth', 1.5);
ylabel('Cuttings Load', 'FontSize', 10);
yyaxis right
plot(time, packoff_index, 'r-', 'LineWidth', 1);
hold on;
plot([time(1), time(end)], [1.0, 1.0], 'r--', 'LineWidth', 1.5);
hold off;
ylabel('Pack-off Index', 'FontSize', 10);
xlabel('Время', 'FontSize', 10);
title('Загрузка шлама и индекс риска прихвата', 'FontSize', 12);
grid on;

fig_handles.timeseries = fig1;

%% График 2: Risk Timeline
fig2 = figure('Position', [100, 100, 1200, 700], 'Visible', 'off');

if ~isempty(final_events)
    subplot(2,1,1);
    bar(final_events.start_time, final_events.risk_score, 'FaceColor', [0.8 0.2 0.2]);
    ylabel('Risk Score', 'FontSize', 10);
    title('Уровень риска обнаруженных осложнений', 'FontSize', 12);
    grid on;
    ylim([0 100]);
    
    subplot(2,1,2);
    event_types = categorical(final_events.event_type);
    bar(final_events.start_time, double(event_types), 'FaceColor', [0.2 0.5 0.8]);
    ylabel('Тип осложнения', 'FontSize', 10);
    xlabel('Время', 'FontSize', 10);
    title('Типы обнаруженных осложнений', 'FontSize', 12);
    grid on;
    
    unique_types = categories(event_types);
    yticks(1:length(unique_types));
    yticklabels(unique_types);
else
    text(0.5, 0.5, 'Осложнения не обнаружены', ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
    axis off;
end

fig_handles.risk_timeline = fig2;

fprintf('    Графики построены успешно\n');

end
