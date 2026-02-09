/*
 * create.js
 * Copyright (c) 2019 james@firefly-iii.org
 *
 * This file is part of Firefly III (https://github.com/firefly-iii).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/** global: Modernizr, currencies */

$(document).ready(function () {
    "use strict";
    $(".content-wrapper form input:enabled:visible:first").first().focus().select();
    if (!Modernizr.inputtypes.date) {
        $('input[type="date"]').datepicker(
            {
                dateFormat: 'yy-mm-dd'
            }
        );
    }
    // change the 'ffInput_opening_balance' text based on the
    // selection of the direction.
    $("#ffInput_liability_direction").change(triggerDirection);
    triggerDirection();

    // Preferred chart color toggle
    togglePreferredChartColor();
    $('#ffInput_use_preferred_chart_color').change(togglePreferredChartColor);
});

function togglePreferredChartColor() {
    var checkbox = $('#ffInput_use_preferred_chart_color');
    var holder = $('#preferred_chart_color_holder');
    var input = $('#ffInput_preferred_chart_color');
    if (checkbox.length === 0 || holder.length === 0 || input.length === 0) {
        return;
    }
    var enabled = checkbox.is(':checked');
    holder.toggle(enabled);
    input.prop('disabled', !enabled);

    // If user enables it and it's the browser default, choose a nicer default.
    if (enabled) {
        var val = (input.val() || '').toLowerCase();
        if (val === '' || val === '#000000') {
            input.val(randomHexColor());
        }
    }
}

function randomHexColor() {
    // Prefer crypto for better randomness.
    if (window.crypto && window.crypto.getRandomValues) {
        var bytes = new Uint8Array(3);
        window.crypto.getRandomValues(bytes);
        return '#' + Array.from(bytes).map(function (b) {
            return b.toString(16).padStart(2, '0');
        }).join('');
    }

    // Fallback.
    var n = Math.floor(Math.random() * 0x1000000);
    return '#' + n.toString(16).padStart(6, '0');
}


function triggerDirection() {
    let obj = $("#ffInput_liability_direction");
    let direction = obj.val();
    console.log('Direction is now ' + direction);
    if('credit' === direction) {
        $('label[for="ffInput_opening_balance"]').text(iAmOwed);
    }
    if('debit' === direction) {
        $('label[for="ffInput_opening_balance"]').text(iOwe);
    }
}
