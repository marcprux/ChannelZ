
![ChannelZ: Lightweight Reactive Swift](data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NUWVBFIHN2ZyBQVUJMSUMgIi0vL1czQy8vRFREIFNWRyAxLjEvL0VOIiAiaHR0cDovL3d3dy53My5vcmcvR3JhcGhpY3MvU1ZHLzEuMS9EVEQvc3ZnMTEuZHRkIj4KPHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHdpZHRoPSIzMDAiIGhlaWdodD0iODgiICB4bWw6c3BhY2U9InByZXNlcnZlIj4KICAgIDxkZWZzPgogICAgICAgIDxmaWx0ZXIgaWQ9ImluZmluaXR5U2hhZG93LW91dGVyIiBmaWx0ZXJVbml0cz0idXNlclNwYWNlT25Vc2UiPgogICAgICAgICAgICA8ZmVHYXVzc2lhbkJsdXIgc3RkRGV2aWF0aW9uPSIxLjc1IiAvPgogICAgICAgICAgICA8ZmVPZmZzZXQgZHg9IjIuMSIgZHk9IjIuMSIgcmVzdWx0PSJibHVyIiAvPgogICAgICAgICAgICA8ZmVGbG9vZCBmbG9vZC1jb2xvcj0icmdiKDAsIDUxLCAwKSIgZmxvb2Qtb3BhY2l0eT0iMC40NyIgLz4KICAgICAgICAgICAgPGZlQ29tcG9zaXRlIGluMj0iYmx1ciIgb3BlcmF0b3I9ImluIiByZXN1bHQ9ImNvbG9yU2hhZG93IiAvPgogICAgICAgICAgICA8ZmVDb21wb3NpdGUgaW49IlNvdXJjZUdyYXBoaWMiIGluMj0iY29sb3JTaGFkb3ciIG9wZXJhdG9yPSJvdmVyIiAvPgogICAgICAgIDwvZmlsdGVyPgogICAgPC9kZWZzPgogICAgPHBhdGggaWQ9ImNoYW5uZWxaUGF0aCIgc3Ryb2tlPSJub25lIiBmaWxsPSJyZ2IoNDQsIDQ0LCA0NCkiIGQ9Ik0gNTAuNyw0LjkxIEwgNTIuNDYsMTEuMzkgQyA1Mi4wMywxNS4wNCA1MC44OCwyMC4wNSA0OS4wMywyNi40MiA0Ny41OCwyMy4wMiA0Ni4wNywxOS45IDQ0LjQ5LDE3LjA3IDQwLjYyLDE1LjUxIDM2LjgyLDE0LjczIDMzLjA5LDE0LjczIDI3LDE0LjczIDIyLjI0LDE2LjUzIDE4LjgyLDIwLjEyIDE1LjM5LDIzLjczIDEzLjY3LDI3Ljk2IDEzLjY3LDMyLjggMTMuNjcsMzUuNDYgMTQuMzksMzcuNzUgMTUuODMsMzkuNjYgMTcuMjYsNDEuNTUgMjAsNDMuMzEgMjQuMDQsNDQuOTMgMjguMSw0Ni41NSAzMy4xOCw0Ny43OCAzOS4yNyw0OC42IDQxLjMsNDguODkgNDMuMzgsNDkuMTIgNDUuNTEsNDkuMyA0Ny42NCw0OS40NyA0OS45OCw0OS42MSA1Mi41MSw0OS43MSA1NS4wNSw0OS44MSA1Ny40Myw0OS44NiA1OS42Myw0OS44NiBMIDU0LjQ4LDU2LjYyIEMgNDYuODYsNTguMDUgMzkuNjcsNTguNzYgMzIuOTIsNTguNzYgMjMuOTksNTguNzYgMTcuNDcsNTcuMDUgMTMuMzQsNTMuNjMgOS4xOCw1MC4yNCA3LjEsNDUuODIgNy4xLDQwLjM5IDcuMSwzNC4zOCA4LjgzLDI4LjQ2IDEyLjI5LDIyLjY0IDE1LjcxLDE2LjgyIDIwLjQsMTIuMyAyNi4zNSw5LjA3IDMyLjMxLDUuODUgMzguMjgsNC4yNCA0NC4yNSw0LjI0IDQ2LjI1LDQuMjQgNDguMzksNC40NiA1MC43LDQuOTEgWiBNIDU5LjIyLDguMDIgTCA2OS4xMyw0LjkxIDY4LjgzLDE2LjA1IDY4LjgzLDIzLjI1IDczLjU1LDE4LjM2IDczLjksMTguMzYgQyA3Ny44OSwxOS41OSA4MC41MSwyMC44OSA4MS43OCwyMi4yNiA4My4wNSwyMy42NCA4My42OSwyNi4wMyA4My42OSwyOS40MSA4My42OSwzMC42IDgzLjUsMzIuNjcgODMuMTMsMzUuNjIgODIuOTIsMzcuMTggODIuNzQsMzkuNCA4Mi42LDQyLjI3IDc5Ljc1LDQ0LjYzIDc2LjU3LDQ2Ljg4IDczLjA1LDQ5LjAxIDczLjkxLDQyLjA1IDc0LjQxLDM3LjU5IDc0LjU1LDM1LjYyIEwgNzMuNDYsMjguNjcgQyA3My4zNiwyOC4yNCA3Mi44LDI2LjU0IDcxLjc2LDIzLjU1IDcwLjQyLDI1LjMyIDY5LjQ0LDI2LjUzIDY4LjgzLDI3LjE1IEwgNjguODMsMzQuNTYgQyA2OC44MywzNC42NiA2OC44MSwzNS4zNSA2OC43NywzNi42NCA2OC43MiwzNy44MyA2OC42OSwzOC44IDY4LjY5LDM5LjU0IDY4LjY5LDQwLjE1IDY4Ljc0LDQxLjMgNjguODMsNDMgNjYuNzQsNDMuMDggNjMuMjUsNDMuNDggNTguMzQsNDQuMiA1OC42NCw0MS44MiA1OC44NCwzOC42OCA1OC45NiwzNC44IDU5LjA2LDMwLjg5IDU5LjE1LDIxLjk2IDU5LjIyLDguMDIgWiBNIDk2LjIzLDI1LjM2IEwgOTYuODcsMzYuODggQyA5Ny45NCwzNS42OSA5OS4wMSwzNC4zNCAxMDAuMDYsMzIuODUgMTAxLjEyLDMxLjM1IDEwMi4wMiwyOS45NSAxMDIuNzYsMjguNjQgMTAxLjY4LDI3LjEgOTkuNTEsMjYuMDEgOTYuMjMsMjUuMzYgWiBNIDk2LjM0LDE4LjMgQyA5Ni42NCwxOC4zOCA5OC40LDE4LjcyIDEwMS42NSwxOS4zMyAxMDQuNTgsMTkuODYgMTA2LjUxLDIwLjI3IDEwNy40NSwyMC41NiAxMDguMzYsMjAuODkgMTA5LjIzLDIxLjQyIDExMC4wNSwyMi4xNCAxMTAuODcsMjIuODYgMTExLjQ5LDIzLjg4IDExMS45LDI1LjE5IDExMi4zMSwyNi40OCAxMTIuNTEsMjguMjIgMTEyLjUxLDMwLjQzIEwgMTEyLjM3LDM5LjA0IEMgMTEyLjM3LDQwLjA2IDExMi40Nyw0MS4yNSAxMTIuNjYsNDIuNjIgMTEwLjg0LDQyLjkxIDEwNy41MSw0My43NSAxMDIuNjcsNDUuMTQgMTAzLjAyLDQyLjQ2IDEwMy4yLDM4Ljc4IDEwMy4yLDM0LjA5IDEwMi44NywzNC42NCAxMDEuOSwzNS43OSAxMDAuMywzNy41NSA5OC43LDM5LjMxIDk2LjQxLDQxLjcxIDkzLjQ0LDQ0Ljc2IDkxLjE2LDQ0LjE1IDg5LjQsNDMuNTcgODguMTcsNDMgODguMDksNDIuMjYgODcuOTMsNDEuMTEgODcuNywzOS41NCA4Ny4zNywzNy4xIDg3LjIsMzQuODkgODcuMiwzMi45MiA4Ny4yLDMwLjA3IDg3LjgsMjcuNjcgODguOTksMjUuNzEgOTAuMTQsMjMuNzggOTIuNTksMjEuMzEgOTYuMzQsMTguMyBaIE0gMTI0LjE3LDE5LjA5IEwgMTI2Ljk5LDE4LjI0IDEyNi45OSwyMi4wOCBDIDEyNy41MywyMS43NSAxMjguNTEsMjEuMTggMTI5LjkyLDIwLjM4IDEzMC4zOSwyMC4xMyAxMzAuODQsMTkuODYgMTMxLjI5LDE5LjU2IEwgMTMzLjc4LDE4LjA3IEMgMTM1LjYsMTguMzIgMTM2Ljk5LDE4LjYzIDEzNy45NCwxOS4wMSAxMzguODYsMTkuMzggMTM5LjYyLDE5LjkzIDE0MC4yMywyMC42OCAxNDAuODIsMjEuNCAxNDEuMjIsMjIuMTMgMTQxLjQzLDIyLjg3IDE0MS42MywyMy41NCAxNDEuNzIsMjQuNjQgMTQxLjcyLDI2LjE4IDE0MS43MiwyOC4wMiAxNDEuNTUsMzAuMTkgMTQxLjIsMzIuNjkgMTQwLjgzLDM1LjM0IDE0MC42MiwzNy42MyAxNDAuNTgsMzkuNTQgTCAxMzUuMTYsNDMgMTM0LjM0LDQzLjU2IEMgMTMyLjc4LDQ0LjYzIDEzMS41LDQ1LjM2IDEzMC41LDQ1Ljc1IDEzMS42NCw0MC4zNCAxMzIuMiwzNi4xMSAxMzIuMiwzMy4wNCAxMzIuMiwyOS4zNSAxMzEuMzksMjYuMTEgMTI5Ljc3LDIzLjMxIDEyOS43MSwyMy4zOSAxMjkuMzYsMjMuNzQgMTI4LjcyLDI0LjM3IEwgMTI4LjE5LDI0Ljk1IDEyNi45OSwyNi4xNSAxMjcuMTMsNDMgQyAxMjMuOTUsNDMuMSAxMjAuNjQsNDMuNTcgMTE3LjIsNDQuNDEgMTE3LjIsNDMuMzkgMTE3LjIxLDQyLjcyIDExNy4yMyw0Mi4zOCAxMTcuMjcsNDEuMTcgMTE3LjI5LDQwLjQ1IDExNy4yOSw0MC4yMiBMIDExNy4yOSwzOS41NCBDIDExNy4yMywzOC43MiAxMTcuMiwzOC4xNSAxMTcuMiwzNy44MSBMIDExNy4yLDMwLjkgQyAxMTcuMiwyNy40IDExNy4xNCwyNC4yNyAxMTcuMDMsMjEuNSAxMTcuMjgsMjEuNDIgMTE3LjU3LDIxLjMzIDExNy45MSwyMS4yMiAxMTguMjQsMjEuMTEgMTE4LjYxLDIwLjk5IDExOS4wMywyMC44NSAxMTkuNDUsMjAuNzEgMTE5LjksMjAuNTYgMTIwLjM3LDIwLjM4IEwgMTI0LjE3LDE5LjA5IFogTSAxNTIuOTIsMTkuMDkgTCAxNTUuNzMsMTguMjQgMTU1LjczLDIyLjA4IEMgMTU2LjI3LDIxLjc1IDE1Ny4yNSwyMS4xOCAxNTguNjYsMjAuMzggMTU5LjEzLDIwLjEzIDE1OS41OCwxOS44NiAxNjAuMDMsMTkuNTYgTCAxNjIuNTIsMTguMDcgQyAxNjQuMzQsMTguMzIgMTY1LjczLDE4LjYzIDE2Ni42OCwxOS4wMSAxNjcuNiwxOS4zOCAxNjguMzYsMTkuOTMgMTY4Ljk3LDIwLjY4IDE2OS41NiwyMS40IDE2OS45NiwyMi4xMyAxNzAuMTcsMjIuODcgMTcwLjM3LDIzLjU0IDE3MC40NiwyNC42NCAxNzAuNDYsMjYuMTggMTcwLjQ2LDI4LjAyIDE3MC4yOSwzMC4xOSAxNjkuOTQsMzIuNjkgMTY5LjU3LDM1LjM0IDE2OS4zNiwzNy42MyAxNjkuMzIsMzkuNTQgTCAxNjMuOSw0MyAxNjMuMDgsNDMuNTYgQyAxNjEuNTIsNDQuNjMgMTYwLjI0LDQ1LjM2IDE1OS4yNCw0NS43NSAxNjAuMzgsNDAuMzQgMTYwLjk0LDM2LjExIDE2MC45NCwzMy4wNCAxNjAuOTQsMjkuMzUgMTYwLjEzLDI2LjExIDE1OC41MSwyMy4zMSAxNTguNDUsMjMuMzkgMTU4LjEsMjMuNzQgMTU3LjQ2LDI0LjM3IEwgMTU2LjkzLDI0Ljk1IDE1NS43MywyNi4xNSAxNTUuODcsNDMgQyAxNTIuNjksNDMuMSAxNDkuMzgsNDMuNTcgMTQ1Ljk0LDQ0LjQxIDE0NS45NCw0My4zOSAxNDUuOTUsNDIuNzIgMTQ1Ljk3LDQyLjM4IDE0Ni4wMSw0MS4xNyAxNDYuMDMsNDAuNDUgMTQ2LjAzLDQwLjIyIEwgMTQ2LjAzLDM5LjU0IEMgMTQ1Ljk3LDM4LjcyIDE0NS45NCwzOC4xNSAxNDUuOTQsMzcuODEgTCAxNDUuOTQsMzAuOSBDIDE0NS45NCwyNy40IDE0NS44OCwyNC4yNyAxNDUuNzcsMjEuNSAxNDYuMDIsMjEuNDIgMTQ2LjMxLDIxLjMzIDE0Ni42NSwyMS4yMiAxNDYuOTgsMjEuMTEgMTQ3LjM1LDIwLjk5IDE0Ny43NywyMC44NSAxNDguMTksMjAuNzEgMTQ4LjY0LDIwLjU2IDE0OS4xMSwyMC4zOCBMIDE1Mi45MiwxOS4wOSBaIE0gMTgzLjc2LDI0LjEgTCAxODMsMzEuMjUgQyAxODQuNywzMS4yNSAxODYuNTMsMzEuMTkgMTg4LjQ4LDMxLjA4IDE4OC41MiwyOS43OSAxODguNTQsMjkuMTcgMTg4LjU0LDI5LjIzIDE4OC41NCwyNy41NyAxODguMSwyNi4zMiAxODcuMjIsMjUuNDggMTg2LjMyLDI0LjYyIDE4NS4xNywyNC4xNiAxODMuNzYsMjQuMSBaIE0gMTc0LjkyLDIzLjgxIEwgMTgxLjUxLDE4LjIxIDE4OS4zOSwxOC44IEMgMTkxLjkzLDE5LjAyIDE5My43MywxOS42NSAxOTQuNzgsMjAuNzEgMTk1Ljg3LDIxLjggMTk2LjQyLDIyLjk5IDE5Ni40MiwyNC4yOCAxOTYuNDIsMjQuODUgMTk2LjM0LDI1LjU4IDE5Ni4xOSwyNi40OCAxOTUuOTcsMjcuNTMgMTk1Ljc1LDI5LjEgMTk1LjUxLDMxLjE5IDE5Mi44NCwzMi41OCAxOTAuODEsMzMuMzkgMTg5LjQyLDMzLjYyIDE4OC4wMSwzMy44NiAxODYuNjcsMzMuOTggMTg1LjM4LDMzLjk4IDE4NC44OSwzMy45OCAxODQuMjgsMzMuOTMgMTgzLjU2LDMzLjgzIDE4NS40NywzNi4yMSAxODcuMzQsMzcuNCAxODkuMTYsMzcuNCAxOTEuMywzNy40IDE5My4yNCwzNi41OSAxOTQuOTYsMzQuOTcgTCAxOTUuMTksMzQuOTcgQyAxOTMuMjQsNDEuMDcgMTg5LjYyLDQ0LjExIDE4NC4zNSw0NC4xMSAxODEuNjIsNDQuMTEgMTc5LjYzLDQzLjczIDE3OC40LDQyLjk3IDE3Ny4xNyw0Mi4yMSAxNzYuMjQsNDEuMTEgMTc1LjU5LDM5LjY2IDE3NC45MywzOC4yNSAxNzQuNTksMzUuNTkgMTc0LjU5LDMxLjY2IEwgMTc0Ljc0LDI2LjY1IDE3NC45MiwyMy44MSBaIE0gMjAxLjM0LDcuODQgTCAyMDcuMDgsNi4zOCAyMTEuNDIsNS4yMSAyMTAuMTksMjYuODMgMjA5Ljc1LDM1LjMyIEMgMjExLjIsMzYuMzYgMjEyLjgzLDM3LjQgMjE0LjY0LDM4LjQ2IEwgMjE0LjY0LDM4LjY2IEMgMjEyLjMyLDQwLjgzIDIxMC4zNyw0Mi45NyAyMDguNzgsNDUuMDggMjA2LjA5LDQ0LjUxIDIwNC4wOCw0My4zNSAyMDIuNzUsNDEuNTggMjAxLjQyLDM5LjgxIDIwMC43NiwzNy40MyAyMDAuNzYsMzQuNDUgMjAwLjc2LDMzLjI1IDIwMC44MiwzMS4zIDIwMC45MywyOC41OSAyMDEuMDUsMjUuOTcgMjAxLjE5LDE5LjA1IDIwMS4zNCw3Ljg0IFogTSAyODEuNzMsNDMuMjYgTCAyODIuMDgsNDMuMzUgMjc0LjE1LDU2LjUxIEMgMjczLjc0LDU2LjYyIDI3Mi43NCw1Ni45OCAyNzEuMTYsNTcuNTkgMjY4LjkxLDU4LjQzIDI2Ni44MSw1OS4wNCAyNjQuODYsNTkuNDQgMjYyLjg1LDU5LjgzIDI2MC40MSw2MC4wMiAyNTcuNTMsNjAuMDIgMjU0LjM5LDYwLjAyIDI1MS40MSw1OS43NyAyNDguNiw1OS4yNiAyNDUuODYsNTguNzcgMjQxLjg2LDU3Ljc4IDIzNi41OSw1Ni4yNyAyMzIuNTQsNTUuMTQgMjI5LjQ0LDU0LjM5IDIyNy4yNyw1NC4wMiAyMjUuMTYsNTMuNjYgMjIyLjE3LDUzLjQxIDIxOC4zMSw1My4yNSBMIDIyMi41OCw0Ni4wOCAyNDguMDQsMzcuOTMgMjc0Ljc5LDI5LjQ0IEMgMjcwLjg0LDI4LjY3IDI2Ny4xMSwyNy44NCAyNjMuNiwyNi45NSAyNjAuMDgsMjYuMDUgMjU2LjUyLDI1IDI1Mi45MSwyMy44IDI0OS4yOSwyMi41OSAyNDUuODUsMjEuMzMgMjQyLjU5LDE5Ljk5IDIzOS4zMywxOC42NSAyMzUuNzksMTcuMDUgMjMxLjk2LDE1LjIgMjI0LjY3LDE5LjcxIDIxOS42OCwyMi43IDIxNi45OSwyNC4xNiBMIDIxNi44NCwyMy45NiBDIDIxOS4xOCwyMS42NyAyMjQuNjUsMTUuNzYgMjMzLjI1LDYuMjMgTCAyNDAuMjUsNC40MiBDIDI0Ni4yMyw3LjM1IDI1MS44LDkuODcgMjU2Ljk2LDExLjk5IDI2Mi4xMywxNC4xMSAyNjYuNzksMTUuNzYgMjcwLjk1LDE2Ljk2IDI3NC45NiwxOC4xMSAyNzguOTgsMTkuMTIgMjgzLjAyLDE5Ljk5IDI4Ny4wNywyMC44NiAyOTEuMTIsMjEuNTUgMjk1LjE4LDIyLjA4IDI5Mi42LDI0LjA0IDI4OS43NiwyNi4xMSAyODYuNjYsMjguMzEgMjgzLjU1LDMwLjUgMjgwLjQ4LDMyLjYgMjc3LjQ2LDM0LjU5IDI3Ni44NywzNC43OSAyNzUuODQsMzUuMDkgMjc0LjM3LDM1LjUgMjcyLjg5LDM1LjkxIDI3MS4wMiwzNi40IDI2OC43NCwzNi45OCAyNjYuNDYsMzcuNTYgMjY0LjUzLDM4LjAzIDI2Mi45MiwzOC40IDI2MS4wOSwzOC44MyAyNTkuMTYsMzkuMyAyNTcuMTQsMzkuODEgMjU1LjEyLDQwLjMxIDI1My4xMyw0MC44MSAyNTEuMTgsNDEuMyAyNDkuMjIsNDEuNzkgMjQ3LjEyLDQyLjMzIDI0NC44OCw0Mi45MSAyNDIuNjMsNDMuNSAyNDAuNTIsNDQuMDUgMjM4LjU1LDQ0LjU4IDI0My43Niw0Ni41IDI0Ny45NSw0Ny43MyAyNTEuMTIsNDguMjcgMjU0LjIsNDguODIgMjU3LjU5LDQ5LjA5IDI2MS4yOCw0OS4wOSAyNjkuNzgsNDkuMDkgMjc2LjYsNDcuMTUgMjgxLjczLDQzLjI2IFogTSAyODEuNzMsNDMuMjYiIC8+CiAgICA8cGF0aCBpZD0iaW5maW5pdHlQYXRoIiBzdHJva2U9Im5vbmUiIGZpbGw9InJnYig0NCwgNDQsIDQ0KSIgZmlsdGVyPSJ1cmwoI2luZmluaXR5U2hhZG93LW91dGVyKSIgZD0iTSAxMzMuOCw2OC4xIEMgMTMxLjc5LDcwLjg1IDEyOS44OSw3Mi44MSAxMjguMDksNzMuOTkgMTI2LjI5LDc1LjE2IDEyNC4yOSw3NS43NSAxMjIuMSw3NS43NSAxMTguNzQsNzUuNzUgMTE1Ljg2LDc0LjU5IDExMy40Niw3Mi4yNiAxMTAuNjMsNjkuNTIgMTA5LjIxLDY1LjgzIDEwOS4yMSw2MS4yMSAxMDkuMjEsNTguNTQgMTA5LjcxLDU2LjAyIDExMC43MSw1My42MyAxMTEuNzEsNTEuMjQgMTEzLjEsNDkuMjcgMTE0Ljg2LDQ3LjcyIDExNy41Myw0NS40MyAxMjAuNzYsNDQuMjggMTI0LjU1LDQ0LjI4IDEyNy4zNSw0NC4yOCAxMjkuODksNDUuMDQgMTMyLjE3LDQ2LjU2IDEzNC40Niw0OC4wOCAxMzYuNiw1MC40NCAxMzguNiw1My42NSAxNDAuMzEsNTAuMjYgMTQyLjE4LDQ3LjgyIDE0NC4yMyw0Ni4zNCAxNDYuMjcsNDQuODYgMTQ4Ljc0LDQ0LjEyIDE1MS42NSw0NC4xMiAxNTMuNDcsNDQuMTIgMTU1LjI0LDQ0LjQ4IDE1Ni45Niw0NS4yMiAxNTguNjgsNDUuOTUgMTYwLjE4LDQ2Ljk3IDE2MS40Niw0OC4yOCAxNjQuMzUsNTEuMjcgMTY1Ljc5LDU1LjMgMTY1Ljc5LDYwLjM3IDE2NS43OSw2My4wNyAxNjUuMjYsNjUuNTggMTY0LjIxLDY3LjkgMTYzLjE1LDcwLjIyIDE2MS42Niw3Mi4xNCAxNTkuNzQsNzMuNjcgMTU4LjMsNzQuODEgMTU2LjY1LDc1LjcxIDE1NC43OCw3Ni4zNSAxNTIuOTEsNzYuOTkgMTUxLjA0LDc3LjMxIDE0OS4xNyw3Ny4zMSAxNDYuMjQsNzcuMzEgMTQzLjQzLDc2LjUxIDE0MC43Niw3NC45MSAxMzguMDksNzMuMzEgMTM1Ljc3LDcxLjA0IDEzMy44LDY4LjEgWiBNIDE0MC41Niw1Ni40MSBDIDE0Mi42Miw1OS44NSAxNDQuNTcsNjIuNCAxNDYuNDEsNjQuMDYgMTQ5LjQ1LDY2Ljc4IDE1Mi41Myw2OC4xNCAxNTUuNjYsNjguMTQgMTU3Ljg1LDY4LjE0IDE1OS42Nyw2Ny4zNyAxNjEuMTQsNjUuODQgMTYyLjYxLDY0LjMgMTYzLjM1LDYyLjM5IDE2My4zNSw2MC4wOSAxNjMuMzUsNTcuNzIgMTYyLjMyLDU1LjkgMTYwLjI4LDU0LjYzIDE1OC4yNCw1My4zNiAxNTUuMzEsNTIuNzMgMTUxLjQ5LDUyLjczIDE0OC44NSw1Mi43MyAxNDYuNSw1My4wOSAxNDQuNDUsNTMuODEgMTQyLjk4LDU0LjMxIDE0MS44OCw1NC45NCAxNDEuMTYsNTUuNjkgMTQwLjc0LDU2LjE0IDE0MC41NCw1Ni4zOCAxNDAuNTYsNTYuNDEgWiBNIDEzMS4zMSw2NC41NCBMIDEzMC42Myw2My40MiBDIDEyOC4yOCw1OS40OSAxMjYuMTYsNTYuODUgMTI0LjI3LDU1LjQ5IDEyMi4zNyw1NC4xMyAxMjAuNDEsNTMuNDUgMTE4LjM4LDUzLjQ1IDExNi41Nyw1My40NSAxMTUuMDcsNTQuMDEgMTEzLjksNTUuMTMgMTEzLjIsNTUuOCAxMTIuNjYsNTYuNjUgMTEyLjI2LDU3LjY5IDExMS44NSw1OC43MyAxMTEuNjUsNTkuOCAxMTEuNjUsNjAuODkgMTExLjY1LDYyLjU1IDExMi4yNCw2My44NyAxMTMuNDIsNjQuODYgMTE0LjI3LDY1LjU1IDExNS40Nyw2Ni4xMSAxMTcuMDIsNjYuNTIgMTE4LjU3LDY2LjkzIDEyMC4yNiw2Ny4xNCAxMjIuMSw2Ny4xNCAxMjQuMTksNjcuMTQgMTI2LDY2LjkzIDEyNy41NSw2Ni41IDEyOC43NSw2Ni4xOCAxMjkuNzEsNjUuNzYgMTMwLjQzLDY1LjI2IDEzMS4wNSw2NC44MyAxMzEuMzQsNjQuNTkgMTMxLjMxLDY0LjU0IFogTSAxMzEuMzEsNjQuNTQiIC8+Cjwvc3ZnPgo=)

[![Build Status](https://travis-ci.org/glimpseio/ChannelZ.svg?branch=master)](https://travis-ci.org/glimpseio/ChannelZ)

*ChannelZ: Lightweight Reactive Swift*

### Introduction

ChannelZ is a pure Swift framework for simplifying state and event management in iOS and Mac apps. You can create `Channels` to both native Swift properties and Objective-C properties, and connect those `Channels` using `Conduits`, enabling the underlying values of the properties to be automatically synchronized.

Following is an overview of the API. To get started using ChannelZ in your own project, jump straight to [Setting up ChannelZ](#setting-up-channelz).

#### Example: Basic Usage

```swift
import ChannelZ

let a1 = ∞(Int(0))∞ // create a field channel
let a2 = ∞(Int(0))∞ // create another field channel

a1 <=∞=> a2 // create a two-way conduit between the properties

println(a1.source.value) // the underlying value of the field channel is accessed with the `value` property
a2.source.value = 42 // then changing a2's value…
println(a1.source.value) // …will automatically set a1 to that same value!

assert(a1.source.value == 42)
assert(a2.source.value == 42)
```
<!-- extra backtick to fix Xcode's faulty syntax highlighting `  -->

> **Note**: this documentation is also available as an executable Playground within the ChannelZ framework.

### Operators & Functions

ChannelZ's central operator is **∞**, which can be entered with `Option-5` on the Mac keyboard. Variants of this operator are used throughout the framework, but you can alternatively use functions for all of ChannelZ's operations. The major operators are listed in section [Operator Glossary](#operator-glossary).

#### Example: Usings Functions Instead of ∞

```swift
let b1: ChannelZ<Int> = channelField(Int(0))
let b2: ChannelZ<Int> = channelField(Int(0))

let b1b2: Receptor = conduit(b1, b2)

b1.source.value
b2.source.value = 99
b1.source.value

assert(b1.source.value == 99)
assert(b2.source.value == 99)

b1b2.unsubscribe() // you can manually disconnect the conduit if you like
```
<!--`-->

### Objective-C, KVO, and ChannelZ

The above examples demonstrate creating channels from two separate Swift properties and keeping them in sync by creaing a conduit. In addition to Swift properties, you can also create channels to Objective-C properties that support Cocoa's [Key-Value Observing](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html) protocol.


#### Example: Objective-C KVO

```swift
import Foundation

class SomeClass : NSObject {
    dynamic var intField: Int = 0
}

// create two separate instances of our ObjC class
let sc1 = SomeClass()
let sc2 = SomeClass()

sc1∞sc1.intField <=∞=> sc2∞sc2.intField

sc2.intField
sc1.intField += 123
sc2.intField

assert(sc1.intField == sc2.intField)
```
<!--`-->

### KVO Details

KVO is handled somewhat differently from Swift property channeling. Since there is no equivalent of KVO in Swift, channeling requires that the underlying Swift value be wrapped in a ChannelZ reference so that the property can be tracked. In Objective-C's KVO system, the owning class itself is the reference that holds the properties.

ChannelZ makes an effort to automatically discover the name of the property on the right side of the `∞` channel operator. This only works for top-level keys, and not for keyPaths that span multiple levels. Similiarly to using the Swift functions in lieu of operators, you can also use the `channelz` method declared in an extension on `NSObject` for KVO property channeling.

#### Example: Objective-C KVO with Functions

```swift
let sc3 = SomeClass()
let sc4 = SomeClass()

let sc3z = sc3.channelz(sc3.intField, keyPath: "intField")
let sc4z = sc4.channelz(sc4.intField, keyPath: "intField")

conduit(sc3z, sc4z)

sc3.intField
sc4.intField += 789
sc3.intField

assert(sc3.intField == sc4.intField)
```
<!--`-->

### Mixing Swift & Objective-C

ChannelZ allows synchronization between properties in Swift and Objective-C instances.

#### Example: Creating a Conduit between a Swift property and Objective-C property

```swift
class StringClass : NSObject {
    dynamic var stringField = ""
}

struct StringStruct {
    let stringChannel = ∞("")∞
}

let scl1 = StringClass()
let sst1 = StringStruct()

scl1∞scl1.stringField <=∞=> sst1.stringChannel


sst1.stringChannel.source.value
scl1.stringField += "ABC"
sst1.stringChannel.source.value

assert(sst1.stringChannel.source.value == scl1.stringField)
```
<!--`-->

The above is an example if a bi-directional conduit using the `<=∞=>` operator. You can also create a uni-directional conduit that only synchronizes state changes in one direction using the `∞=>` and `<=∞` operators.

#### Example: A Unidirectional Condit

```swift
let scl2 = StringClass()
let sst2 = StringStruct()

scl2∞scl2.stringField ∞=> sst2.stringChannel

scl2.stringField += "XYZ"
assert(sst2.stringChannel.source.value == scl2.stringField, "stringField conduit to stringChannel")

sst2.stringChannel.source.value = "QRS"
assert(sst2.stringChannel.source.value != scl2.stringField, "conduit is unidirectional")
```
<!--`-->

### Channeling between Different Types

Thus far, we have only seen channel conduits between identical types. You can also create mappings on channels that permit creating conduits between the types. Channels define `map`, `filter`, and `combine` functions.

#### Example: Mapping between Different Types

```swift
class ObjcIntClass : NSObject {
    dynamic var intField: Int = 0
}

struct SwiftStringClass {
    let stringChannel = ∞("")∞
}

let ojic = ObjcIntClass()
let swsc = SwiftStringClass()

(ojic∞ojic.intField).map({ "\($0)" }) <=∞=> (swsc.stringChannel).map({ $0.toInt() ?? 0 })

ojic.intField += 55
swsc.stringChannel.source.value // will be "55"

swsc.stringChannel.source.value = "89"
ojic.intField // will be 89

```
<!--`-->

#### Example: Observing Button Taps

```swift
import UIKit

let button = UIButton()
button.controlz() ∞> { (event: UIEvent) in println("Tapped Button!") }
```
<!--`-->

Note that `controlz()` method on `UIButton`. This is a category method added by `ChannelZ` to all `UIControl` instances on iOS' `UIKit` and `NSControl` instances on Mac's `AppKit`. The extensions of UIKit and AppKit also permit channeling other control events, which are not normally observable through KVO.

#### Example: Sychronizing a Slider and a Stepper through a Model

```swift
struct ViewModel {
    let amount = ∞(Double(0))∞
    let amountMax = Double(100.0)
}

let vm = ViewModel()

let stepper = UIStepper()
stepper.maximumValue = vm.amountMax
stepper∞stepper.value <=∞=> vm.amount

let slider = UISlider()
slider.maximumValue = Float(vm.amountMax)
slider∞slider.value <~∞~> vm.amount

stepper.value += 25.0
assert(slider.value == 25.0)
assert(vm.amount.source.value == 25.0)

slider.value += 30.0
assert(stepper.value == 55.0)
assert(vm.amount.source.value == 55.0)

println("slider: \(slider.value) stepper: \(stepper.value)")
```
<!--`-->

> The `<~∞~>` operator a variant of the `<=∞=>` operator that coerces between different numeric types. It is used above because `UIStepper.value` is a `Double` and `UISlider.value` is a `Float`. The `<=∞=>` operator respects Swift's design decision to prohibit automatic numeric type coersion and is generally recommended.

Note that channels and Observables are not restricted to a single conduit or subscription. We can supplement the above example with a progress indicator.

#### Example: Adding a UIProgressView channel

```swift
let progbar = UIProgressView()

// UIProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value 
vm.amount.map({ Float($0 / vm.amountMax) }) ∞=> progbar∞progbar.progress

vm.amount.source.value += 20

assert(slider.value == 75.0)
assert(stepper.value == 75.0)
assert(progbar.progress == 0.75)

println("slider: \(slider.value) stepper: \(stepper.value) progress: \(progbar.progress)")
```
<!--`-->


> The `ViewModel` struct above demonstrates using the [Model View ViewModel(MVVM)](https://en.wikipedia.org/wiki/Model_View_ViewModel) variant of the traditional *Model View Control* design pattern for user interfaces. ChannelZ can be used as the data binding layer for implementing MVVM, which has the benefit of being more easily testable and better facilitating the creation of re-usable UI code for cross-platform iOS & Mac apps.

### Memory Management

Receptors are weakly associated with their target objects, so when the objects are released, their subscriptions are also released. Note that when using closures, the standard practice of declaring `[unowned self]` is recommended in order to avert retain cycles in your own code.


### Operator Glossary

Following is a list of the variants of the ∞ operator that is used throughout the ChannelZ framework:

* `∞(SWTYPE)∞`: Wraps the given Swift reference type in a field channel
* `ObjC ∞ ObjC.key`: Creates a channel to the given Objective-C object's auto-detected KVO-compliant key.
* `ObjC ∞ (ObjC.key, "keyPath")`: Creates a channel to the given Objective-C's property with a manually specified keypath.
* `Fz ∞> { (arg: Type) -> Void }`: subscribes a subscription to the given Observable or channel.
* `Fz ∞-> { (arg: Type) -> Void }`: subscribes a subscription to the given Observable or channel and primes it with the current value.
* `Cz1 ∞=> Cz2`: Unidirectionally conduits state from channel `Cz1` to channel `Cz2`.
* `Cz1 ∞=-> Cz2`: Unidirectionally conduits state from channel `Cz1` to channel `Cz2` and primes the subscription.
* `Cz1 <-=∞ Cz2`: Unidirectionally conduits state from channel `Cz2` to channel `Cz1` and primes the subscription.
* `Cz1 <=∞=> Cz2`: Bidirectionally conduits state between channels `Cz1` and `Cz2`.
* `Cz1 <=∞=-> Cz2`: Bidirectionally conduits state between channels `Cz1` and `Cz2` and primes the right side subscription.
* `Cz1 <~∞~> Cz2`: Bidirectionally conduits state between channels `Cz1` and `Cz2` by coercing numeric types.
* `Cz1 <?∞?> Cz2`: Bidirectionally conduits state between channels `Cz1` and `Cz2` by attempting an optional cast.
* `(Cz1 | Cz2) ∞> { (cz1Type?, cz2Type?) -> Void }`: subscribe a subscription to the combination of `Cz1` and `Cz2` such that when either changes, the subscription will be fired.
* `(Cz1 & Cz2) ∞> { (cz1Type, cz2Type) -> Void }`: subscribe a subscription to the combination of `Cz1` and `Cz2` such that when both change, the subscription will be fired.

### Setting up ChannelZ

`ChannelZ` is a single cross-platform iOS & Mac Framework. To set it up in your project, simply add it as a github submodule, drag the `ChannelZ.xcodeproj` into your own project file, add `ChannelZ.framework` to your target's dependencies, and `import ChannelZ` from any Swift file that should use it.

**Set up Git submodule**

1. Open a Terminal window
1. Change to your projects directory `cd /path/to/MyProject`
1. If this is a new project, initialize Git: `git init`
1. Add the submodule: `git submodule add https://github.com/glimpseio/ChannelZ.git ChannelZ`.

**Set up Xcode**

1. Find the `ChannelZ.xcodeproj` file inside of the cloned ChannelZ project directory.
1. Drag & Drop it into the `Project Navigator` (⌘+1).
1. Select your project in the `Project Navigator` (⌘+1).
1. Select your target.
1. Select the tab `Build Phases`.
1. Expand `Link Binary With Libraries`.
1. Add `ChannelZ.framework`
1. Add `import ChannelZ` to the top of your Swift source files.


### FAQ:

1. **Why the Operator ∞?** A common complaint about overloading existing operators (such as +) is that they can defy intuition. ∞ was chosen because it is not used by any other known Swift framework, and so developers are unlikely to have preconceived notions about what it should mean. Also, the infinity symbol is a good metaphor for the infinite nature of modeling state changes over time.
1. **Can I use ChannelZ from Objective-C?** No. ChannelZ uses generic, structs, and enums, none of which can be used from Objective-C code. The framework will interact gracefully with any Objective-C code you have, but you cannot access channels from Objective-C, only from Swift.
1. **Optionals?**
1. **NSMutableDictionary keys?**
1. **System requirements?** ChannelZ requires Xcode 6.1+ with iOS 8.1+ or Mac OS 10.10+.
1. **How is automatic keypath identification done?** In order to turn the code `ob∞ob.someField` into a KVO subscription, we need to figure out that `someField` is equivalent to the `"someField"` key path. This is accomplished by temporarily swizzling the class at the time of channel creation in order to instrument the properties and track which property is accessed by the autoclosure, and then immediately swizzling it back to the original class. This is usually transparent, but may fail on classes that dynamically implement their properties, such as Core Data's '`NSManagedObject`. In those cases, you can always manually specify the key path of a field with the operator variant that takes a tuple with the original value and the name of the property: `ob∞(ob.someField, "someField")`
1. **Automatic Keypath Identification Performance?** `ob∞ob.someField` is about 12x slower than `ob∞(ob.someField, "someField")`
1. **Memory management?** All channels are rooted in a reference type: either a reference wrapper around a Swift value, or by the owning class instance itself for KVO. The reference type owns all the subscribed subscriptions, and they are deallocated whenever the reference is released. You shouldn't need to manually track subscriptions and unsubscribe them, although there is nothing preventing you from doing so if you wish.
1. **Unstable conduit & reentrancy?** A state channel conduit is considered *unstable* when it cannot reach equilibrium. For example, `ob1∞ob1.intField <=∞=> (ob2∞ob2.intField).map({ $0 + 1 })` would mean that setting `ob1.intField` to 1 would set `ob2.intField` to 1, and then the map on the channel would cause `ob1.intField` to be set to 2. This cycle is prevented by limited the levels of re-entrancy that a subscription will allow, and is controlled by the global `ChannelZReentrancyLimit` field, which default to 1. You can change this value globally if you have channel cycles that may take a few passes to settle into equilibrium.
1. **Threading & Queuing?** ChannelZ doesn't touch threads or queues. You can always perform queue jumping yourself in a subscription.
1. **UIKit/AppKit and KVO?** `UIKit`'s `UIControl` and `AppKit`'s `NSControl` are not KVO-compliant for user interaction. For example, the `value` field of a `UISlider` does not receive KVO messages when the user drags the slider. We work around this by supplementing channel subscriptions with an additional Observable for the control events. See the `KeyValueChannelSupplementing` implementation in the `UIControl` extension for an example of how you can supplement your own control events.
1. **Problems?** Please file a Github [ChannelZ issue](https://github.com/mprudhom/ChannelZ/issues/new).
1. **Questions** Please use StackOverflow's [#channelz tag](http://stackoverflow.com/questions/tagged/channelz).

## References

* [Deprecating the Observer Pattern with Scala.React](http://infoscience.epfl.ch/record/176887)
* [Groovy Parallel Systems](http://gpars.codehaus.org/Dataflow)


