import sqlite3

paths = [
    r'C:\StrategyQuantX144\internal\license.db',
    r'C:\StrategyQuantX145\internal\license.db',
    r'C:\StrategyQuantX145\internal\license.db.default',
]
for path in paths:
    print('===', path)
    try:
        con = sqlite3.connect(path)
        rows = list(con.execute('select KEY, VALUE from SETTINGS'))
        print('rows:', len(rows))
        for key, value in rows:
            v = '' if value is None else str(value)
            if len(v) > 12:
                masked = v[:6] + '...' + v[-4:]
            else:
                masked = v
            print('KEY=', repr(key), 'LEN=', len(v), 'MASKED=', repr(masked))
    except Exception as exc:
        print('ERROR', type(exc).__name__, exc)
