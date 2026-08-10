import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-payments',
  standalone: true,
  imports: [CommonModule],
  template: `
    <h1 style="font-size:24px;font-weight:700;margin-bottom:24px;">Payments</h1>
    <div class="grid-4" style="margin-bottom:20px;">
      <div class="card"><div style="color:#64748B;font-size:14px;">Total Revenue</div><div style="font-size:24px;font-weight:700;">₹4,20,000</div></div>
      <div class="card"><div style="color:#64748B;font-size:14px;">This Month</div><div style="font-size:24px;font-weight:700;">₹1,50,000</div></div>
      <div class="card"><div style="color:#64748B;font-size:14px;">Pending</div><div style="font-size:24px;font-weight:700;">₹15,000</div></div>
      <div class="card"><div style="color:#64748B;font-size:14px;">Refunds</div><div style="font-size:24px;font-weight:700;">₹5,000</div></div>
    </div>
    <div class="card"><table><thead><tr><th>Invoice</th><th>Student</th><th>Amount</th><th>Method</th><th>Date</th><th>Status</th></tr></thead><tbody>
      <tr *ngFor="let p of payments"><td>{{p.invoice}}</td><td>{{p.student}}</td><td>{{p.amount}}</td><td>{{p.method}}</td><td>{{p.date}}</td><td><span class="badge badge-success">Success</span></td></tr>
    </tbody></table></div>
  `
})
export class PaymentsComponent {
  payments = [
    { invoice: 'INV-001', student: 'John Doe', amount: '₹4,999', method: 'Razorpay', date: '28 Jul 2026' },
    { invoice: 'INV-002', student: 'Jane Smith', amount: '₹2,999', method: 'Razorpay', date: '27 Jul 2026' },
    { invoice: 'INV-003', student: 'Bob Lee', amount: '₹1,999', method: 'UPI', date: '26 Jul 2026' },
  ];
}