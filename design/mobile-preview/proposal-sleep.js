/* Proposal · Sleep. Every section of the current Sleep screen is still here, in the same
   order of thought (last night, this week, the longer view, your own patterns); what
   changes is that each reading says where it sits. Sample values only. */
(() => {
  const { P, esc, hm, clock, chip, verdictOf, rangeBar, hypnogram, stageRows, checks, trendCard, durationCard, timingCard, scale, frame, dayAxis } = H.p;
  const S = {
    score: 66,
    vitals: [
      ['heart', 'heart', 'Resting heart', 53, 'bpm', [50, 62], [52, 57], 'down'],
      ['fitness', 'activity', 'HRV', 61, 'ms', [35, 75], [44, 58], 'up'],
      ['oxygen', 'drop', 'Blood oxygen', 99, '%', [92, 100], [96, 99], 'up'],
      ['oxygen', 'cloud', 'Breathing', 14, '/min', [10, 20], [13, 15], 'steady'],
      ['stress', 'sun', 'Skin temperature', 34.2, '°C', [32, 36], [33.6, 34.5], 'steady'],
    ],
    week: [286, 344, 441, 292, 574, 521, 526], need: 480,
    fortnight: {
      efficiency: { title: 'Sleep efficiency', tone: 'sleep', icon: 'insights', unit: '%', better: 'up', ceiling: 100, values: [71, 75, 98, 98, 95, 98, 93, 99, 97, 97, 96, 91, 98, 99], previous: 90, normal: [90, 99], span: ['28 Sep', '11 Oct'], period: 'over 14 nights', before: 'the 14 before' },
      regularity: { title: 'Sleep regularity', tone: 'sleep', icon: 'insights', unit: 'SRI', better: 'up', values: [54, 52, 51, 55, 62, 64, 68, 73, 75, 76, 75, 72, 72, 72], previous: 58, normal: [58, 74], span: ['28 Sep', '11 Oct'], period: 'over 14 nights', before: 'the 14 before' },
      hrv: { title: 'Heart-rate variability', tone: 'fitness', icon: 'activity', unit: 'ms', better: 'up', values: [56, 46, 50, 41, 50, 42, 46, 45, 53, 52, 51, 47, 40, 61], previous: 47, normal: [44, 58], span: ['28 Sep', '11 Oct'], period: 'over 14 nights', before: 'the 14 before' },
    },
    offPattern: [['25 Sep', '21:23', '4.9 h early'], ['10 Oct', '21:43', '4.5 h early'], ['8 Oct', '21:55', '4.3 h early'], ['9 Oct', '22:25', '3.8 h early']],
    naps: [['11 Oct', '16:02 to 16:49', 47], ['11 Oct', '08:15 to 09:03', 48], ['7 Oct', '15:45 to 17:15', 90], ['7 Oct', '12:34 to 13:12', 38], ['5 Oct', '17:29 to 18:25', 56]],
    patterns: [
      ['opposite', 'Recovery', 'Resting heart rate', 3, '60 days'],
      ['together', 'Overnight HRV', 'Recovery', 3, '29 days'],
      ['opposite', 'Sleep regularity', 'Sleep debt', 3, '47 days · strongest a day apart'],
      ['opposite', 'Sleep regularity', 'Resting calories', 3, '47 days · strongest a day apart'],
      ['together', 'Overnight blood oxygen', 'Vigorous minutes', 2, '28 days · strongest a day apart'],
    ],
  };
  const jump = () => `<nav class="p-jump" aria-label="On this page">${[['p-night', 'Last night'], ['p-week', 'This week'], ['p-longer', 'Longer view'], ['p-patterns', 'Your patterns']].map(([target, label], index) => `<button data-action="jump" data-target="${target}" ${index ? '' : 'aria-current="true"'}>${label}</button>`).join('')}</nav>`;
  const head = (id, title, note) => `<div class="p-part" id="${id}"><h2>${title}</h2><p>${note}</p></div>`;
  const vitals = () => `<div class="p-vitals">${S.vitals.map(([tone, icon, name, value, unit, [min, max], usual, better]) => {
    const verdict = verdictOf(value, usual, better === 'steady' ? 'up' : better), steady = better === 'steady' && verdict.kind !== 'steady';
    return `<div class="p-vital" data-tone="${tone}"><span class="p-vital-name">${H.icon(icon)}${name}</span><strong>${value}<small> ${unit}</small></strong>
      ${rangeBar({ value, min, max, band: usual, label: `${name} ${value} ${unit}. Your usual range is ${usual[0]} to ${usual[1]}.`, ends: [min, max, `usual ${usual[0]} to ${usual[1]}`] })}
      <small class="p-vital-line"><span class="p-chip ${steady ? 'watch' : verdict.kind}">${verdict.word}</span>${better === 'up' ? 'Higher is better.' : better === 'down' ? 'Lower is better.' : 'Close to your usual is better.'}</small></div>`;
  }).join('')}</div>`;
  const needWeek = () => {
    const y = scale(0, 600, 16, 112);
    let content = frame(y, [0, 240, 480], value => `${value / 60}h`) + `<path class="p-need" d="M4 ${y(S.need).toFixed(1)}H306"/>`;
    S.week.forEach((minutes, index) => {
      const x = 26 + index * 43 - 12, met = minutes >= S.need;
      if (!met) content += `<rect class="p-owed" x="${x}" y="${y(S.need).toFixed(1)}" width="24" height="${(y(minutes) - y(S.need)).toFixed(1)}" rx="4"/>`;
      content += `<rect class="p-bar ${met ? 'met' : 'current'}" x="${x}" y="${y(minutes).toFixed(1)}" width="24" height="${(y(0) - y(minutes)).toFixed(1)}" rx="4"/><text class="p-value" text-anchor="middle" x="${x + 12}" y="${(y(Math.max(minutes, met ? minutes : S.need)) - 5).toFixed(1)}">${met ? '✓' : `−${Math.floor((S.need - minutes) / 60)}:${String((S.need - minutes) % 60).padStart(2, '0')}`}</text>`;
    });
    return `<svg class="p-chart" viewBox="0 0 340 142" role="img" aria-label="Sleep against an 8 hour need on each of the last seven nights">${content}${dayAxis()}</svg>`;
  };
  const lower = name => name.toLowerCase().replace('hrv', 'HRV');
  const short = minutes => minutes < 60 ? `${minutes}m` : hm(minutes);
  const patternRow = ([kind, first, second, strength, span]) => `<div class="p-pattern"><div class="p-pattern-pair"><span>${first}<b>↑</b></span><i></i><span>${second}<b>${kind === 'together' ? '↑' : '↓'}</b></span></div>
    <p>Higher ${lower(first)} usually came with <strong>${kind === 'together' ? 'higher' : 'lower'}</strong> ${lower(second)}.</p>
    <small><span class="p-strength" aria-hidden="true">${[1, 2, 3].map(step => `<i class="${step <= strength ? 'on' : ''}"></i>`).join('')}</span>${strength === 3 ? 'Moved closely' : 'Moved moderately'} · ${span}</small></div>`;
  H.screens['p-sleep'] = () => {
    const night = P.night, total = P.debt.fortnight.reduce((sum, minutes) => sum + minutes, 0), weekShort = S.week.reduce((sum, minutes) => sum + Math.max(0, S.need - minutes), 0), napTotal = S.naps.reduce((sum, nap) => sum + nap[2], 0);
    const panel = (icon, title, body, tone = 'sleep') => `<section class="panel p-panel" data-tone="${tone}"><h3 class="panel-title">${H.icon(icon)}${title}</h3>${body}</section>`;
    return `<div class="p-screen" data-tone="sleep">
      <header class="page-header p-header"><div class="grow"><h1>Sleep</h1><p class="date">Night of Tue, 15 Sep</p></div><a href="#settings" class="icon-button avatar" aria-label="Profile and settings">A</a></header>
      ${jump()}
      <section class="p-sleep-hero" id="p-night"><div class="p-hero-row"><div><p class="p-eyebrow">Time asleep</p><div class="p-big">6<small>h</small> 24<small>m</small></div></div><div class="p-device"><strong>${S.score}</strong><span>Amazfit score</span><small>Device estimate</small></div></div>
        ${rangeBar({ value: 384, min: 240, max: 540, band: [350, 430], label: 'Asleep 6 hours 24 minutes. Your usual range is 5 hours 50 to 7 hours 10.', ends: ['4h', '9h', 'usual 5h 50m to 7h 10m'] })}
        <p class="p-key-line">${chip(verdictOf(384, [350, 430]))} <strong>1h 36m short</strong> of your 8h need.</p>
        <dl class="p-facts"><div><dt>In bed</dt><dd>${clock(night.bed)}</dd></div><div><dt>Up</dt><dd>${clock(night.wake)}</dd></div><div><dt>Time in bed</dt><dd>${hm(night.wake - night.bed)}</dd></div></dl></section>
      ${panel('moon', 'Your night, hour by hour', `${hypnogram(night)}<p class="p-legend">Each block is one stretch in one stage. Higher on the chart is lighter sleep.</p>`)}
      ${panel('moon', 'Every stage, accounted for', `${stageRows(night.stages)}<p class="p-legend">Proportions use the supplied stage total. Stage totals and time-asleep estimates can differ.</p>`)}
      ${panel('check', 'Your four sleep checks', `<p class="p-legend first">The shaded part of each bar is the reference range. The mark is last night.</p>${checks()}<p class="p-legend">Four independent checks, not a combined score. The 7 to 9h check differs from the 8h sleep-need reference.</p>`)}
      ${panel('heart', 'Your body overnight', `<p class="p-legend first">The shaded part of each bar is your own last 14 nights. The mark is last night.</p>${vitals()}`, 'heart')}
      ${head('p-week', 'This week', '5 to 11 Oct · seven measured nights')}
      ${panel('clock', 'Sleep need & debt', `<div class="p-two"><div><p class="p-eyebrow">This week</p><div class="p-mid">${hm(weekShort)}</div><small>short of your 8h need, in total</small></div><div><p class="p-eyebrow">Last 14 nights</p><div class="p-mid">${(total / 60).toFixed(1)}<small> h</small></div><small>the modelled debt · about ${hm(total / 14)} a night</small></div></div>${needWeek()}<p class="p-legend">The faint part of a bar is what that night still needed. A tick means the night met 8h. The week's figure and the 14-night model are two different sums.</p>`)}
      ${durationCard(P.week)}${timingCard(P.week)}
      ${panel('clock', 'Nights off your pattern', `<div class="p-two"><div><p class="p-eyebrow">Typical bedtime band</p><div class="p-mid">5.4<small> h wide</small></div><small>loose (3h or more) · your biggest lever</small></div><div><p class="p-eyebrow">Usual times</p><div class="p-mid">02:15</div><small>bed · wake about 07:58</small></div></div><table class="p-table"><thead><tr><th>Night</th><th>In bed</th><th>Against your usual</th></tr></thead><tbody>${S.offPattern.map(([day, bed, gap]) => `<tr><td>${day}</td><td>${bed}</td><td>${gap}</td></tr>`).join('')}</tbody></table><p class="p-legend">Nights more than two hours from your usual bedtime.</p>`)}
      ${head('p-longer', 'Beyond a single night', '28 Sep to 11 Oct · 14 nights')}
      ${trendCard(S.fortnight.efficiency)}${trendCard(S.fortnight.regularity)}${trendCard(S.fortnight.hrv)}
      ${panel('moon', 'Naps & your day', `<div class="p-two"><div><p class="p-eyebrow">Last 7 days</p><div class="p-mid">${hm(napTotal)}</div><small>in ${S.naps.length} naps</small></div><div><p class="p-eyebrow">Longest</p><div class="p-mid">${hm(Math.max(...S.naps.map(nap => nap[2])))}</div><small>on 7 Oct</small></div></div><table class="p-table"><thead><tr><th>Day</th><th>When</th><th>Length</th></tr></thead><tbody>${S.naps.map(([day, when, minutes]) => `<tr><td>${day}</td><td>${when}</td><td>${short(minutes)}</td></tr>`).join('')}</tbody></table>`)}
      ${head('p-patterns', 'In your own data', 'What moved together in your history. Never what caused what.')}
      <section class="panel p-panel" data-tone="oxygen">${S.patterns.map(patternRow).join('')}<p class="p-legend">Single-subject and observational: patterns found in your history, not effects shown in a trial.</p></section>
      <p class="p-more">${H.link('Sleep recommendations', 'actions')}</p>
      ${H.footer()}</div>`;
  };
})();
