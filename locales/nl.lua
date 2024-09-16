local Translations = {
    error = {
        unknown_player = 'Onbekende Speler',
    },
    menu = {
        choose_loadout = 'Kies Loadout',
        own_loadout = 'Eigen Loadout',
        own_loadout_txt = 'Ga in de arena met je eigen gear',
        random_loadout = 'Random Loadout',
        random_loadout_txt = 'Ga in de arena met een random loadout',
        exit_arena = 'Verlaat Arena',
        includes = 'Omvat:',
    },
    inarena = {
        shotandout = 'Je bent geraakt en ligt uit het spel!',
        shot = 'Je bent geraakt!',
    },
    command = {
        description_exitarena = 'Een speler geforceerd de arena uit smijten (Admin Only)',
        help_exitarena = 'Speler ID',
        invalid_player_id = 'Ongeldige speler ID.',
        player_removed = 'Speler is geforceerd verwijderd uit de arena.',
        player_not_in_arena = 'Speler bevindt zich niet in de airsoft arena.',
    },
    notifications = {
        entered = 'Je hebt de Airsoft Arena betreden.',
        exited = 'Je hebt de Airsoft Arena verlaten.',
        force_exit = 'U bent geforceerd verwijderd uit de airsoft arena.',
        cannot_afford = 'Je hebt niet genoeg geld voor deze loadout!',
    }
}

if GetConvar('qb_locale', 'en') == 'nl' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end