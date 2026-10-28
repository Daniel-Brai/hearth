import { createContext, useContext } from 'react';

export type MenuContextValue = { close: () => void };

export const MenuContext = createContext<MenuContextValue | null>(null);

export const useMenu = () => useContext(MenuContext);
