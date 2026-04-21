#!/usr/bin/env python3
"""Generate Morning Dashboard .shortcut plist file.

The shortcut:
1. Finds today's calendar events
2. Loops through events to build calendar HTML
3. Generates a self-contained HTML page with embedded JS for weather/sports
4. Displays via Quick Look

Usage:
    python3 generate_shortcut.py
    # Then on macOS: shortcuts sign --mode anyone --input MorningDashboard.shortcut --output MorningDashboard_signed.shortcut
"""

import uuid as _uuid
import os

FFFC = '\ufffc'

def genuuid():
    return str(_uuid.uuid4()).upper()

def xmlesc(s):
    return (s.replace('&', '&amp;')
             .replace('<', '&lt;')
             .replace('>', '&gt;')
             .replace('"', '&quot;'))

# Pre-generate all UUIDs
U = {
    'cal_events': genuuid(),
    'repeat_grp': genuuid(),
    'repeat_start': genuuid(),
    'fmt_start': genuuid(),
    'fmt_end': genuuid(),
    'evt_text': genuuid(),
    'repeat_end': genuuid(),
    'get_calhtml': genuuid(),
    'full_html': genuuid(),
}

def attachment(ouuid, oname, otype='ActionOutput', aggr=None):
    """Build an attachment dict XML."""
    parts = []
    if aggr:
        parts.append('                        <key>Aggrandizements</key>')
        parts.append('                        <array>')
        for a in aggr:
            parts.append('                            <dict>')
            for k, v in a.items():
                parts.append(f'                                <key>{xmlesc(k)}</key>')
                parts.append(f'                                <string>{xmlesc(v)}</string>')
            parts.append('                            </dict>')
        parts.append('                        </array>')
    parts.append(f'                        <key>OutputName</key>')
    parts.append(f'                        <string>{xmlesc(oname)}</string>')
    parts.append(f'                        <key>OutputUUID</key>')
    parts.append(f'                        <string>{ouuid}</string>')
    parts.append(f'                        <key>Type</key>')
    parts.append(f'                        <string>{otype}</string>')
    return '\n'.join(parts)

def token_attachment(param, ouuid, oname, otype='ActionOutput', aggr=None):
    """WFTextTokenAttachment for a parameter."""
    return f"""                <key>{xmlesc(param)}</key>
                <dict>
                    <key>Value</key>
                    <dict>
{attachment(ouuid, oname, otype, aggr)}
                    </dict>
                    <key>WFSerializationType</key>
                    <string>WFTextTokenAttachment</string>
                </dict>"""

def token_string_single(param, ouuid, oname, otype='ActionOutput'):
    """WFTextTokenString with a single variable at position 0."""
    return f"""                <key>{xmlesc(param)}</key>
                <dict>
                    <key>Value</key>
                    <dict>
                        <key>attachmentsByRange</key>
                        <dict>
                            <key>{{0, 1}}</key>
                            <dict>
{attachment(ouuid, oname, otype)}
                            </dict>
                        </dict>
                        <key>string</key>
                        <string>{FFFC}</string>
                    </dict>
                    <key>WFSerializationType</key>
                    <string>WFTextTokenString</string>
                </dict>"""

def build_text_with_vars(param, template_parts):
    """Build WFTextTokenString from list of (text, None) or (FFFC, attachment_info) parts.
    attachment_info = (uuid, name, type, aggr)
    """
    full_str = ''
    attachments = []
    for part in template_parts:
        if part[1] is None:
            full_str += part[0]
        else:
            pos = len(full_str)
            full_str += FFFC
            attachments.append((pos, part[1]))

    lines = [f'                <key>{xmlesc(param)}</key>']
    lines.append('                <dict>')
    lines.append('                    <key>Value</key>')
    lines.append('                    <dict>')
    lines.append('                        <key>attachmentsByRange</key>')
    lines.append('                        <dict>')
    for pos, att in attachments:
        ouuid, oname = att[0], att[1]
        otype = att[2] if len(att) > 2 else 'ActionOutput'
        aggr = att[3] if len(att) > 3 else None
        lines.append(f'                            <key>{{{pos}, 1}}</key>')
        lines.append('                            <dict>')
        if aggr:
            lines.append('                                <key>Aggrandizements</key>')
            lines.append('                                <array>')
            for a in aggr:
                lines.append('                                    <dict>')
                for k, v in a.items():
                    lines.append(f'                                        <key>{xmlesc(k)}</key>')
                    lines.append(f'                                        <string>{xmlesc(v)}</string>')
                lines.append('                                    </dict>')
                lines.append('                                </array>')
        lines.append(f'                                <key>OutputName</key>')
        lines.append(f'                                <string>{xmlesc(oname)}</string>')
        lines.append(f'                                <key>OutputUUID</key>')
        lines.append(f'                                <string>{ouuid}</string>')
        lines.append(f'                                <key>Type</key>')
        lines.append(f'                                <string>{otype}</string>')
        lines.append('                            </dict>')
    lines.append('                        </dict>')
    lines.append('                        <key>string</key>')
    lines.append(f'                        <string>{xmlesc(full_str)}</string>')
    lines.append('                    </dict>')
    lines.append('                    <key>WFSerializationType</key>')
    lines.append('                    <string>WFTextTokenString</string>')
    lines.append('                </dict>')
    return '\n'.join(lines)

def action(identifier, params):
    return f"""        <dict>
            <key>WFWorkflowActionIdentifier</key>
            <string>{identifier}</string>
            <key>WFWorkflowActionParameters</key>
            <dict>
{params}
            </dict>
        </dict>"""


# ============================================================
# BUILD ACTIONS
# ============================================================
actions = []

# 1. Comment
actions.append(action('is.workflow.actions.comment', """                <key>WFCommentActionText</key>
                <string>Morning Dashboard — Gathers calendar events, then displays a dashboard with weather, calendar, and sports data via Quick Look HTML.</string>"""))

# 2. Find Calendar Events (today, sorted by start date)
actions.append(action('is.workflow.actions.filter.calendarevents', f"""                <key>UUID</key>
                <string>{U['cal_events']}</string>
                <key>WFContentItemSortOrder</key>
                <string>Oldest First</string>
                <key>WFContentItemSortProperty</key>
                <string>Start Date</string>
                <key>WFContentItemFilter</key>
                <dict>
                    <key>Value</key>
                    <dict>
                        <key>WFActionParameterFilterPrefix</key>
                        <integer>1</integer>
                        <key>WFContentPredicateBoundedDate</key>
                        <false/>
                        <key>WFActionParameterFilterTemplates</key>
                        <array>
                            <dict>
                                <key>Operator</key>
                                <integer>1002</integer>
                                <key>Property</key>
                                <string>Start Date</string>
                                <key>Removable</key>
                                <true/>
                            </dict>
                        </array>
                    </dict>
                    <key>WFSerializationType</key>
                    <string>WFContentPredicateTableTemplate</string>
                </dict>"""))

# 3. Repeat with Each (start) — loop through calendar events
actions.append(action('is.workflow.actions.repeat.each', f"""                <key>UUID</key>
                <string>{U['repeat_start']}</string>
                <key>GroupingIdentifier</key>
                <string>{U['repeat_grp']}</string>
                <key>WFControlFlowMode</key>
                <integer>0</integer>
{token_attachment('WFInput', U['cal_events'], 'Calendar Events')}"""))

# 4. Format Date — start time of current event
actions.append(action('is.workflow.actions.formatdate', f"""                <key>UUID</key>
                <string>{U['fmt_start']}</string>
                <key>WFDateFormatStyle</key>
                <string>Custom</string>
                <key>WFDateFormat</key>
                <string>h:mm a</string>
{token_attachment('WFDate', U['repeat_start'], 'Repeat Item', aggr=[
    {'PropertyName': 'Start Date', 'Type': 'WFPropertyVariableAggrandizement'}
])}"""))

# 5. Format Date — end time of current event
actions.append(action('is.workflow.actions.formatdate', f"""                <key>UUID</key>
                <string>{U['fmt_end']}</string>
                <key>WFDateFormatStyle</key>
                <string>Custom</string>
                <key>WFDateFormat</key>
                <string>h:mm a</string>
{token_attachment('WFDate', U['repeat_start'], 'Repeat Item', aggr=[
    {'PropertyName': 'End Date', 'Type': 'WFPropertyVariableAggrandizement'}
])}"""))

# 6. Text — build HTML for one calendar event
# Template: <div class="cal-event"><div class="cal-event-title">TITLE</div><div class="cal-event-time">START – END</div></div>\n
evt_template = build_text_with_vars('WFTextActionText', [
    ('<div class="cal-event"><div class="cal-event-title">', None),
    (FFFC, (U['repeat_start'], 'Repeat Item', 'ActionOutput', [
        {'PropertyName': 'Title', 'Type': 'WFPropertyVariableAggrandizement'}
    ])),
    ('</div><div class="cal-event-time">', None),
    (FFFC, (U['fmt_start'], 'Formatted Date')),
    (' \u2013 ', None),  # en-dash
    (FFFC, (U['fmt_end'], 'Formatted Date')),
    ('</div></div>\n', None),
])
actions.append(action('is.workflow.actions.gettext', f"""                <key>UUID</key>
                <string>{U['evt_text']}</string>
{evt_template}"""))

# 7. Append to Variable "CalendarHTML"
actions.append(action('is.workflow.actions.appendvariable', f"""                <key>WFVariableName</key>
                <string>CalendarHTML</string>
{token_attachment('WFInput', U['evt_text'], 'Text')}"""))

# 8. Repeat with Each (end)
actions.append(action('is.workflow.actions.repeat.each', f"""                <key>UUID</key>
                <string>{U['repeat_end']}</string>
                <key>GroupingIdentifier</key>
                <string>{U['repeat_grp']}</string>
                <key>WFControlFlowMode</key>
                <integer>2</integer>"""))

# 9. Get Variable "CalendarHTML"
actions.append(action('is.workflow.actions.getvariable', f"""                <key>UUID</key>
                <string>{U['get_calhtml']}</string>
                <key>WFVariable</key>
                <dict>
                    <key>Value</key>
                    <dict>
                        <key>Type</key>
                        <string>Variable</string>
                        <key>VariableName</key>
                        <string>CalendarHTML</string>
                    </dict>
                    <key>WFSerializationType</key>
                    <string>WFTextTokenAttachment</string>
                </dict>"""))

# 10. Build the full HTML page
# The HTML contains inline JS that fetches weather + sports APIs at render time
# Calendar data is the only thing embedded from Shortcuts

# Read the HTML template
html_page = open(os.path.join(os.path.dirname(__file__), 'dashboard_page.html')).read()

# Find the CALENDAR_PLACEHOLDER and replace with FFFC
PLACEHOLDER = '<!--CALENDAR_DATA-->'
assert PLACEHOLDER in html_page, f"Placeholder {PLACEHOLDER} not found in dashboard_page.html"
cal_pos = html_page.index(PLACEHOLDER)
html_with_var = html_page[:cal_pos] + FFFC + html_page[cal_pos + len(PLACEHOLDER):]

# Build the text token string manually since the HTML is huge
full_html_param = build_text_with_vars('WFTextActionText', [
    (html_with_var[:cal_pos], None),
    (FFFC, (U['get_calhtml'], 'CalendarHTML', 'Variable')),
    (html_with_var[cal_pos + 1:], None),  # +1 to skip the FFFC we inserted
])

actions.append(action('is.workflow.actions.gettext', f"""                <key>UUID</key>
                <string>{U['full_html']}</string>
{full_html_param}"""))

# 11. Quick Look
actions.append(action('is.workflow.actions.quicklook', f"""{token_attachment('WFInput', U['full_html'], 'Text')}"""))


# ============================================================
# ASSEMBLE PLIST
# ============================================================
actions_xml = '\n'.join(actions)

plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>WFWorkflowActions</key>
    <array>
{actions_xml}
    </array>
    <key>WFWorkflowClientVersion</key>
    <string>2700.0.4</string>
    <key>WFWorkflowHasOutputFallback</key>
    <false/>
    <key>WFWorkflowIcon</key>
    <dict>
        <key>WFWorkflowIconGlyphNumber</key>
        <integer>59511</integer>
        <key>WFWorkflowIconStartColor</key>
        <integer>4282601983</integer>
    </dict>
    <key>WFWorkflowImportQuestions</key>
    <array/>
    <key>WFWorkflowMinimumClientVersion</key>
    <integer>900</integer>
    <key>WFWorkflowMinimumClientVersionString</key>
    <string>900</string>
    <key>WFWorkflowName</key>
    <string>Morning Dashboard</string>
    <key>WFWorkflowOutputContentItemClasses</key>
    <array/>
    <key>WFWorkflowTypes</key>
    <array/>
</dict>
</plist>
"""

outpath = os.path.join(os.path.dirname(__file__), 'MorningDashboard.shortcut')
with open(outpath, 'w', encoding='utf-8') as f:
    f.write(plist)

print(f"Generated: {outpath}")
print(f"Actions: {len(actions)}")
print(f"UUIDs: {U}")
print()
print("Next steps:")
print("  1. Transfer MorningDashboard.shortcut to your Mac")
print("  2. Run: shortcuts sign --mode anyone --input MorningDashboard.shortcut --output MorningDashboard_signed.shortcut")
print("  3. AirDrop or transfer the signed file to your iPhone")
print("  4. Open the signed file to import into Shortcuts")
