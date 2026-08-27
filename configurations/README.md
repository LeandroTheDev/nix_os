# Commands
## Clean garbage on store
- nix-collect-garbage -d

## Repair packages
- nix-store --verify --check-contents --repair

# Usefull packages for 'packages.nix'
## Compilations
```
    gnumake
    go
    gcc
```

## Some security dependencies
```
    gnupg
    pinentry-curses
```

## Random dependencies
```
    jq
```
