function formations = generate_formation_model()
% GENERATE_FORMATION_MODEL Создаёт таблицу геологических пластов
%
% Выход:
%   formations - таблица с свойствами пластов

    % Определение пластов
    top_md = [2000; 2350; 2600; 3000; 3400];
    bottom_md = [2350; 2600; 3000; 3400; 5000];
    
    lithology = {'shale'; 'sandstone'; 'carbonate'; 'shale'; 'sandstone'};
    
    % Механические свойства (MPa)
    ucs = [35; 55; 90; 45; 60];
    
    % Абразивность (0-1)
    abrasiveness = [0.3; 0.7; 0.8; 0.4; 0.6];
    
    % Буримость (относительная, 1.0 = норма)
    drillability = [1.2; 0.9; 0.55; 1.0; 0.85];
    
    % Газовый потенциал (0-1)
    gas_potential = [0.2; 0.8; 0.3; 0.5; 0.9];
    
    % Индекс проницаемости (0-1)
    permeability_index = [0.1; 0.8; 0.2; 0.3; 0.7];
    
    % Индекс нестабильности (0-1)
    instability_index = [0.4; 0.2; 0.1; 0.6; 0.3];
    
    % Градиенты давления
    pp_gradient = [1.05; 1.10; 1.08; 1.12; 1.15];
    fg_gradient = [1.65; 1.70; 1.75; 1.68; 1.72];
    
    % Создание таблицы
    formations = table();
    formations.TopMD = top_md;
    formations.BottomMD = bottom_md;
    formations.Lithology = lithology;
    formations.UCS_MPa = ucs;
    formations.Abrasiveness = abrasiveness;
    formations.Drillability = drillability;
    formations.GasPotential = gas_potential;
    formations.PermeabilityIndex = permeability_index;
    formations.InstabilityIndex = instability_index;
    formations.PPGradient = pp_gradient;
    formations.FGGradient = fg_gradient;
    
    fprintf('    Создано %d пластов\n', height(formations));
end
