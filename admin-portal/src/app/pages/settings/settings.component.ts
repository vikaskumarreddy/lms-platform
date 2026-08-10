import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule],
  template: `
    <h1 style='font-size:24px;font-weight:700;margin-bottom:24px;'>Settings</h1>
    <div class='grid-2'>
      <div class='card'>
        <h3 style='margin-bottom:16px;'>Institute Profile</h3>
        <div style='display:flex;flex-direction:column;gap:12px;'>
          <input placeholder='Institute Name' value='Axisora Forge Academy' style='padding:10px;border:1px solid #E2E8F0;border-radius:8px;'>
          <input placeholder='Email' value='contact@axisoraforge.com' style='padding:10px;border:1px solid #E2E8F0;border-radius:8px;'>
          <input placeholder='Phone' value='+91 9876543210' style='padding:10px;border:1px solid #E2E8F0;border-radius:8px;'>
          <button class='btn btn-primary'>Save Changes</button>
        </div>
      </div>
      <div class='card'>
        <h3 style='margin-bottom:16px;'>Payment Settings</h3>
        <div style='display:flex;flex-direction:column;gap:12px;'>
          <input placeholder='Razorpay Key ID' style='padding:10px;border:1px solid #E2E8F0;border-radius:8px;'>
          <input placeholder='Razorpay Key Secret' type='password' style='padding:10px;border:1px solid #E2E8F0;border-radius:8px;'>
          <button class='btn btn-primary'>Save Payment Settings</button>
        </div>
      </div>
    </div>
  `
})
export class SettingsComponent {}
