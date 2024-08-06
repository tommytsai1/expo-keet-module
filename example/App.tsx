import React, { useEffect } from 'react';
import { getAll } from 'expo-keet-module';
import { WebView } from 'expo-keet-module';

export default function App() {
  useEffect(() => {
    async function fetchCookies() {
      try {
        console.log('Calling getAll...');
        const cookies = await getAll(true);
        console.log('Cookies:', cookies);
      } catch (error) {
        console.error('Error calling getAll:', error);
      }
    }

    fetchCookies();
  }, []);


  return (
    <WebView
      style={{ flex: 1 }}
      url="https://x.com"
      onLoad={event => alert(`loaded ${event.nativeEvent.url}`)}
    />
  );
}