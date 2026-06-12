%% ЭКСТРЕННОЕ СОЗДАНИЕ ГРАФИКОВ
% Загружает существующий MAT и создаёт PNG НЕМЕДЛЕННО

fprintf('Загрузка MAT...\n');
load('../output/drilling_diagnostics_results.mat');

fprintf('Построение графиков...\n');
fig_handles = plot_diagnostics(results.drilling_data, results.features_data, results.final_events);

fprintf('Сохранение PNG...\n');
try
    set(fig_handles.timeseries, 'Visible', 'off');
    print(fig_handles.timeseries, '../output/diagnostic_timeseries.png', '-dpng', '-r150');
    fprintf('✓ diagnostic_timeseries.png создан\n');
catch ME
    warning('Ошибка: %s', ME.message);
end

try
    set(fig_handles.risk_timeline, 'Visible', 'off');
    print(fig_handles.risk_timeline, '../output/risk_timeline.png', '-dpng', '-r150');
    fprintf('✓ risk_timeline.png создан\n');
catch ME
    warning('Ошибка: %s', ME.message);
end

fprintf('\nГРАФИКИ ГОТОВЫ в ../output/\n');
fprintf('Откройте: open ../output/diagnostic_timeseries.png\n');
