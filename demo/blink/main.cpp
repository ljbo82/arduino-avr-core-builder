/*
 * Copyright 2021 Leandro José Britto de Oliveira
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include <Arduino.h>

void setup() {
	pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
	static bool state = false;
	digitalWrite(LED_BUILTIN, state ? LOW : HIGH);
	state = !state;
	delay(100);
}

